import Foundation
import AVFoundation
import SwiftUI

/// Voice commands for Guidance panel navigation (no backend round-trip).
private enum GuidanceVoiceCommand {
    case nextStep
    case previousStep

    static func parse(_ text: String) -> GuidanceVoiceCommand? {
        let t = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let nextPhrases = ["next step", "next", "go forward", "forward"]
        let prevPhrases = ["previous step", "previous", "go back", "back", "last step"]
        if nextPhrases.contains(where: { t.contains($0) }) && !prevPhrases.contains(where: { t.contains($0) }) {
            return .nextStep
        }
        if prevPhrases.contains(where: { t.contains($0) }) {
            return .previousStep
        }
        return nil
    }
}

@Observable
@MainActor
final class VoiceOrbModel {

    enum OrbState { case idle, listening, thinking, speaking }

    var orbState: OrbState = .idle
    var statusText = "Tap orb to speak"
    var errorText: String? = nil

    weak var copilotModel: CrisisCopilotModel?

    private var audioEngine = AVAudioEngine()
    private var audioFile: AVAudioFile?
    private var recordingURL: URL?
    private var audioPlayer: AVAudioPlayer?
    private let backendService = BackendService()

    // MARK: - Public

    /// Request microphone permission early so the user sees the prompt on launch (call from onAppear).
    func requestMicrophonePermissionIfNeeded() {
        #if os(macOS)
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined else { return }
        AVCaptureDevice.requestAccess(for: .audio) { _ in }
        #else
        guard AVAudioApplication.recordPermission == .undetermined else { return }
        AVAudioApplication.requestRecordPermission { _ in }
        #endif
    }

    /// Called once on launch — speaks the opening greeting and initialises the session.
    func autoGreet() async {
        guard let model = copilotModel else { return }
        model.startEmergency()
        let text = model.messages.last?.text ?? "Hey! I'm your personal doctor. What's going on?"
        await playTTS(text)
    }

    func handleTap() {
        switch orbState {
        case .idle:      Task { await requestAndStart() }
        case .listening: Task { await stopAndProcess() }
        case .speaking:  stopPlayback()
        case .thinking:  break
        }
    }

    // MARK: - Recording

    private func requestAndStart() async {
        #if os(macOS)
        let granted = await withCheckedContinuation { cont in
            AVCaptureDevice.requestAccess(for: .audio) { cont.resume(returning: $0) }
        }
        #else
        let granted = await AVAudioApplication.requestRecordPermission()
        #endif
        guard granted else {
            errorText = "Microphone access denied — allow it in Settings."
            return
        }
        startRecording()
    }

    private func startRecording() {
        audioEngine = AVAudioEngine()

        let inputNode = audioEngine.inputNode
        var format = inputNode.outputFormat(forBus: 0)
        if format.sampleRate == 0 || format.channelCount == 0 {
            format = AVAudioFormat(standardFormatWithSampleRate: 16_000, channels: 1)!
        }

        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")
        recordingURL = tmpURL

        do {
            audioFile = try AVAudioFile(forWriting: tmpURL, settings: format.settings)
        } catch {
            errorText = "Could not create audio file."
            return
        }

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buf, _ in
            try? self?.audioFile?.write(from: buf)
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
            orbState = .listening
            statusText = "Listening… tap again when done"
            errorText = nil
        } catch {
            errorText = "Could not start microphone."
            cleanupEngine()
        }
    }

    private func stopAndProcess() async {
        let url = recordingURL
        recordingURL = nil
        cleanupEngine()   // stop engine + remove tap (no more writes)
        audioFile = nil   // flush + close the file

        guard let url else {
            orbState = .idle; statusText = "Tap orb to speak"; return
        }

        orbState = .thinking
        statusText = "transcribing…"

        let data = (try? Data(contentsOf: url)) ?? Data()
        try? FileManager.default.removeItem(at: url)

        guard !data.isEmpty else {
            orbState = .idle; statusText = "nothing heard — tap to try again"; return
        }

        let transcript = await backendService.speechToText(audioData: data) ?? ""
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            orbState = .idle; statusText = "nothing heard — tap to try again"; return
        }

        if let nav = GuidanceVoiceCommand.parse(trimmed) {
            await handleGuidanceVoice(nav)
            return
        }

        await processText(trimmed)
    }

    private func handleGuidanceVoice(_ command: GuidanceVoiceCommand) async {
        guard let model = copilotModel else {
            orbState = .idle; statusText = "Tap orb to speak"; return
        }
        switch command {
        case .nextStep:
            model.guidanceGoNext()
            await playTTS("Next step.")
        case .previousStep:
            model.guidanceGoBack()
            await playTTS("Previous step.")
        }
    }

    private func cleanupEngine() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        audioEngine.reset()
    }

    // MARK: - LLM

    private func processText(_ text: String) async {
        guard let model = copilotModel else { return }
        orbState = .thinking
        statusText = "thinking…"

        let beforeCount = model.messages.count
        model.sendUserMessage(text)

        // Poll for assistant reply (max 30 s)
        var waited = 0
        while model.messages.count < beforeCount + 2, waited < 30_000 {
            try? await Task.sleep(for: .milliseconds(200))
            waited += 200
        }

        let reply = model.messages.last(where: { $0.role == .assistant })?.text ?? ""
        if reply.isEmpty {
            orbState = .idle
            statusText = "Tap orb to speak"
        } else {
            await playTTS(reply)
        }
    }

    // MARK: - TTS

    private func playTTS(_ text: String) async {
        orbState = .speaking
        statusText = "speaking…"
        errorText = nil

        if let data = await backendService.requestTTS(text: String(text.prefix(500))) {
            do {
                audioPlayer = try AVAudioPlayer(data: data)
                audioPlayer?.volume = 1.0
                audioPlayer?.prepareToPlay()
                audioPlayer?.play()
                while audioPlayer?.isPlaying == true {
                    try? await Task.sleep(for: .milliseconds(100))
                }
            } catch {
                errorText = "Playback error: \(error.localizedDescription)"
            }
        } else {
            errorText = "TTS failed — is the backend running at port 8000?"
        }

        orbState = .idle
        statusText = "Tap orb to speak"
    }

    private func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        orbState = .idle
        statusText = "Tap orb to speak"
    }
}
