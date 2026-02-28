//
//  BackendService.swift
//  Survivor MVP
//
//  API client for Crisis Copilot backend: chat, TTS, report.
//  Fallback to stubs in model when backend is unavailable.
//

import Foundation

struct ChatResponsePayload: Decodable {
    let response: ResponsePayload
    let session_id: String

    struct ResponsePayload: Decodable {
        let spoken_text: String
        let metadata: MetadataPayload?
    }

    struct MetadataPayload: Decodable {
        let step: Int?
        let urgency: String?
        let image_query: String?
        let category: String?
        let display_text: String?
    }
}

@MainActor
final class BackendService {
    private let baseURL: String
    private let session: URLSession
    private let decoder: JSONDecoder

    private static let defaultBaseURLValue = "http://localhost:8000"

    init(baseURL: String? = nil) {
        let url = baseURL ?? Self.defaultBaseURLValue
        self.baseURL = url.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.session = URLSession.shared
        self.decoder = JSONDecoder()
    }

    /// POST /api/chat — send user message, get AI response and session_id.
    /// Returns nil on any failure (network, decode, 4xx/5xx).
    func sendMessage(sessionId: String?, text: String) async -> (responseText: String, metadata: ChatResponsePayload.MetadataPayload?, sessionId: String)? {
        let url = URL(string: "\(baseURL)/api/chat")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let body: [String: Any?] = [
            "session_id": sessionId,
            "message": text,
        ]
        let validBody = body.compactMapValues { $0 }
        guard let data = try? JSONSerialization.data(withJSONObject: validBody) else { return nil }
        request.httpBody = data
        request.timeoutInterval = 30

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return nil
            }
            let decoded = try decoder.decode(ChatResponsePayload.self, from: data)
            return (
                decoded.response.spoken_text,
                decoded.response.metadata,
                decoded.session_id
            )
        } catch {
            return nil
        }
    }

    /// POST /api/chat with empty message to start session and get greeting + session_id.
    func startSession() async -> (greeting: String, sessionId: String)? {
        let result = await sendMessage(sessionId: nil, text: "")
        guard let result else { return nil }
        return (result.responseText, result.sessionId)
    }

    /// GET /api/tts?text=... — returns audio data (mp3) or nil.
    func requestTTS(text: String) async -> Data? {
        guard let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/api/tts?text=\(encoded)") else {
            return nil
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return nil
            }
            return data
        } catch {
            return nil
        }
    }

    /// POST /api/report/{session_id}/generate — returns PDF data or nil.
    func generateReport(sessionId: String) async -> Data? {
        let url = URL(string: "\(baseURL)/api/report/\(sessionId)/generate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return nil
            }
            return data
        } catch {
            return nil
        }
    }
}
