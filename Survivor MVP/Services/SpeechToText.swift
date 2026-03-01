//
//  SpeechToText.swift
//  Survivor MVP
//
//  Protocol for STT (e.g. Apple Speech). Used by CrisisCopilotModel.
//

import Foundation

/// Protocol for speech-to-text (microphone → transcript).
protocol SpeechToText: Sendable {
    /// Start capturing and recognizing. Call stop() to finish and get transcript.
    func start()
    /// Stop capturing and return the final transcript. May throw if recognition failed.
    func stop() async throws -> String
    /// Live partial transcript while listening (e.g. for "Listening…" UI).
    var partialTranscript: String { get }
}
