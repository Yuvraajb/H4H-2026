//
//  TextToSpeech.swift
//  Survivor MVP
//
//  Protocol for TTS (e.g. ElevenLabs). Used by CrisisCopilotModel.
//

import Foundation

/// Protocol for text-to-speech playback.
protocol TextToSpeech: Sendable {
    /// Speak the given text (fetches audio and plays). Non-blocking; returns when playback has started or failed.
    func speak(_ text: String) async throws
    /// Stop current playback if any.
    func stop()
    /// True while audio is playing.
    var isSpeaking: Bool { get }
}
