//
//  AppleSpeechTranscriber.swift
//  Survivor MVP
//
//  Speech-to-text using SFSpeechRecognizer + AVAudioEngine. macOS/iOS.
//

import Foundation
import Speech
import AVFoundation

@MainActor
final class AppleSpeechTranscriber: SpeechToText {
    private var engine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer: SFSpeechRecognizer?
    private var stopContinuation: CheckedContinuation<String, Error>?
    /// True only while a tap is installed; avoid removeTap() when there is no tap (crashes with nullptr == Tap()).
    private var hasTapInstalled = false

    private(set) var partialTranscript: String = ""

    init(locale: Locale = .current) {
        self.speechRecognizer = SFSpeechRecognizer(locale: locale)
    }

    static func requestAuthorization() async -> Bool {
        await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }
    }

    static func microphonePermissionGranted() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return true
        case .notDetermined:
            return await withCheckedContinuation { cont in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    cont.resume(returning: granted)
                }
            }
        default: return false
        }
    }

    func start() {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else { return }
        // Use a fresh engine each session to avoid tap state crashes (nullptr == Tap()).
        if hasTapInstalled {
            cleanupEngine()
        }
        let newEngine = AVAudioEngine()
        self.engine = newEngine
        partialTranscript = ""
        stopContinuation = nil
        let inputNode = newEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest?.shouldReportPartialResults = true
        recognitionRequest?.requiresOnDeviceRecognition = false
        let request = recognitionRequest!
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            Task { @MainActor in
                // Ignore callbacks from a previous session (different request).
                guard self.recognitionRequest === request else { return }
                if let result = result {
                    let text = result.bestTranscription.formattedString
                    self.partialTranscript = text
                    if result.isFinal {
                        self.finishWithResult(text)
                    }
                }
                if let error = error {
                    self.finishWithErrorOrEmpty(error)
                }
            }
        }
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        hasTapInstalled = true
        newEngine.prepare()
        try? newEngine.start()
    }

    /// Remove tap (only if installed), stop engine, clear state. Safe to call multiple times.
    private func cleanupEngine() {
        guard let eng = engine else { return }
        if hasTapInstalled {
            eng.inputNode.removeTap(onBus: 0)
            hasTapInstalled = false
        }
        if eng.isRunning {
            eng.stop()
        }
        engine = nil
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
    }

    func stop() async throws -> String {
        let result = try await withCheckedThrowingContinuation { cont in
            stopContinuation = cont
            recognitionRequest?.endAudio()
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                if let c = self.stopContinuation {
                    self.stopContinuation = nil
                    c.resume(returning: self.partialTranscript)
                }
            }
        }
        cleanupEngine()
        return result
    }

    private func finishWithResult(_ text: String) {
        if let cont = stopContinuation {
            stopContinuation = nil
            cont.resume(returning: text)
        }
    }

    private func finishWithError(_ error: Error) {
        if let cont = stopContinuation {
            stopContinuation = nil
            cont.resume(throwing: error)
        }
    }

    /// On cancellation / no speech / multi-request (216), return partial transcript instead of throwing.
    private func finishWithErrorOrEmpty(_ error: Error) {
        let err = error as NSError
        let desc = err.localizedDescription.lowercased()
        let isCancelled = err.domain == "kAFAssistantErrorDomain" && err.code == 216
        let isNoSpeech = desc.contains("no speech") || desc.contains("no speech detected")
        let isOperationCancelled = desc.contains("cancel") || err.code == 1
        if isCancelled || isNoSpeech || isOperationCancelled {
            if let cont = stopContinuation {
                stopContinuation = nil
                cont.resume(returning: partialTranscript)
            }
        } else {
            finishWithError(error)
        }
    }
}
