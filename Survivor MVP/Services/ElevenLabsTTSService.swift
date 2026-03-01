//
//  ElevenLabsTTSService.swift
//  Survivor MVP
//
//  TextToSpeech implementation using ElevenLabs API. Requires ELEVENLABS_API_KEY in environment.
//

import Foundation
import AVFoundation

@MainActor
final class ElevenLabsTTSService: TextToSpeech {
    private let baseURL = "https://api.elevenlabs.io/v1/text-to-speech"
    private let defaultVoiceId = "21m00Tcm4TlvDq8ikWAM" // Rachel
    private var voiceId: String
    private var apiKey: String?
    private var player: AVAudioPlayer?
    private(set) var isSpeaking: Bool = false

    var isConfigured: Bool { apiKey != nil && !(apiKey?.isEmpty ?? true) }

    init(voiceId: String? = nil, apiKey: String? = nil) {
        self.voiceId = voiceId ?? defaultVoiceId
        self.apiKey = apiKey
            ?? ProcessInfo.processInfo.environment["ELEVENLABS_API_KEY"]
            ?? Self.loadAPIKeyFromEnvFile()
    }

    /// Load ELEVENLABS_API_KEY from a .env file so keys stay out of source.
    private static func loadAPIKeyFromEnvFile() -> String? {
        let cwd = FileManager.default.currentDirectoryPath
        let cwdSurvivor = (cwd as NSString).appendingPathComponent("Survivor MVP")
        var candidates: [String] = [
            cwd,
            cwdSurvivor,
            Bundle.main.bundleURL.deletingLastPathComponent().path,
        ]
        #if os(macOS)
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let homeDesktop = (home as NSString).appendingPathComponent("Desktop")
        let projectPath = (homeDesktop as NSString).appendingPathComponent("SurvivorMVP/Survivor MVP")
        candidates.append(contentsOf: [home, projectPath])
        #endif
        let filenames = [".env", ".crisiscopilot_env"]
        for dir in candidates {
            for name in filenames {
                let path = (dir as NSString).appendingPathComponent(name)
                guard let contents = try? String(contentsOfFile: path, encoding: .utf8) else { continue }
                for line in contents.components(separatedBy: .newlines) {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    guard trimmed.hasPrefix("ELEVENLABS_API_KEY="), !trimmed.hasPrefix("ELEVENLABS_API_KEY=#") else { continue }
                    let value = trimmed.dropFirst("ELEVENLABS_API_KEY=".count)
                        .trimmingCharacters(in: CharacterSet(charactersIn: "\"' "))
                    if !value.isEmpty { return value }
                }
            }
        }
        return nil
    }

    func setVoiceId(_ id: String) {
        voiceId = id.isEmpty ? defaultVoiceId : id
    }

    func speak(_ text: String) async throws {
        stop()
        guard let key = apiKey, !key.isEmpty else {
            throw TTSError.missingApiKey
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let url = URL(string: "\(baseURL)/\(voiceId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(key, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")
        let body: [String: Any] = [
            "text": trimmed,
            "model_id": "eleven_monolingual_v1"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 30
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw TTSError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            if let msg = String(data: data, encoding: .utf8) {
                throw TTSError.apiError(status: http.statusCode, message: msg)
            }
            throw TTSError.apiError(status: http.statusCode, message: "Unknown error")
        }
        try playAudio(data: data)
    }

    func stop() {
        player?.stop()
        player = nil
        isSpeaking = false
    }

    private func playAudio(data: Data) throws {
        player = try AVAudioPlayer(data: data)
        player?.prepareToPlay()
        player?.play()
        isSpeaking = true
        Task { @MainActor in
            while player?.isPlaying == true {
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            isSpeaking = false
        }
    }

    enum TTSError: Error {
        case missingApiKey
        case invalidResponse
        case apiError(status: Int, message: String)
    }
}
