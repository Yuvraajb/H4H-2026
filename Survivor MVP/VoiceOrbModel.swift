import Foundation
import AVFoundation
import Speech
import SwiftUI

@Observable
@MainActor
final class VoiceOrbModel {

    enum OrbState { case idle, listening, thinking, speaking }

    var orbState: OrbState = .idle
    var statusText = "tap to speak"
    var errorText: String? = nil

    weak var copilotModel: CrisisCopilotModel?

    private var audioEngine = AVAudioEngine() // recreated each session
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var audioPlayer: AVAudioPlayer?
    private var partialTranscript = ""
    private let backendService = BackendService()

    // MARK: - Public

    /// Called once on launch — plays opening greeting via TTS and initialises the session.
    func autoGreet() async {
        guard let model = copilotModel else { return }
        model.startEmergency()
        // startEmergency appends the greeting message; grab it and speak it
        let text = model.messages.last?.text ?? "Hey! I'm your personal doctor. What's going on?"
        await playTTS(text)
    }

    func handleTap() {
        switch orbState {
        case .idle:     Task { await requestAndStart() }
        case .listening: Task { await stopAndProcess() }
        case .speaking: stopPlayback()
        case .thinking: break
        }
    }

    // MARK: - Recording

    private func requestAndStart() async {
        let speechAuth = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        guard speechAuth == .authorized else {
            errorText = "Speech recognition not authorized in Settings."
            return
        }
        #if os(macOS)
        let micGranted = await withCheckedContinuation { cont in
            AVCaptureDevice.requestAccess(for: .audio) { cont.resume(returning: $0) }
        }
        #else
        let micGranted = await AVAudioApplication.requestRecordPermission()
        #endif
        guard micGranted else {
            errorText = "Microphone access denied — allow it in Settings."
            return
        }
        startRecording()
    }

    private func startRecording() {
        // Fresh engine each session — avoids stale input node format (sampleRate = 0 crash)
        audioEngine = AVAudioEngine()
        recognitionTask?.cancel()
        recognitionTask = nil
        partialTranscript = ""

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        recognitionRequest = req

        recognitionTask = speechRecognizer?.recognitionTask(with: req) { [weak self] result, error in
            Task { @MainActor [weak self] in
                if let r = result {
                    self?.partialTranscript = r.bestTranscription.formattedString
                }
                if let e = error, (e as NSError).code != 216 { // 216 = cancelled
                    self?.orbState = .idle
                    self?.statusText = "tap to speak"
                }
            }
        }

        let inputNode = audioEngine.inputNode

        // Validate format — sampleRate can be 0 before the engine warms up
        var format = inputNode.outputFormat(forBus: 0)
        if format.sampleRate == 0 || format.channelCount == 0 {
            format = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
        }

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { buf, _ in
            req.append(buf)
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
            orbState = .listening
            statusText = "listening… tap to stop"
            errorText = nil
        } catch {
            errorText = "Could not start microphone."
            cleanupEngine()
        }
    }

    private func stopAndProcess() async {
        let text = partialTranscript
        cleanupEngine()

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            orbState = .idle
            statusText = "nothing heard — tap to try again"
            return
        }
        await processText(trimmed)
    }

    private func cleanupEngine() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        audioEngine.reset()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
    }

    // MARK: - LLM

    private func processText(_ text: String) async {
        guard let model = copilotModel else { return }
        orbState = .thinking
        statusText = "thinking…"

        let beforeCount = model.messages.count
        model.sendUserMessage(text) // fires Task internally; user msg appended synchronously

        // Wait for the assistant response (max 30 s, poll every 200 ms)
        var waited = 0
        while model.messages.count < beforeCount + 2, waited < 30_000 {
            try? await Task.sleep(for: .milliseconds(200))
            waited += 200
        }

        let reply = model.messages.last(where: { $0.role == .assistant })?.text ?? ""
        if reply.isEmpty {
            orbState = .idle
            statusText = "tap to speak"
        } else {
            await playTTS(reply)
        }
    }

    // MARK: - TTS

    private func playTTS(_ text: String) async {
        orbState = .speaking
        statusText = "speaking…"

        if let data = await backendService.requestTTS(text: String(text.prefix(500))) {
            do {
                audioPlayer = try AVAudioPlayer(data: data)
                audioPlayer?.play()
                while audioPlayer?.isPlaying == true {
                    try? await Task.sleep(for: .milliseconds(100))
                }
            } catch {}
        }

        orbState = .idle
        statusText = "tap to speak"
    }

    private func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        orbState = .idle
        statusText = "tap to speak"
    }
}
