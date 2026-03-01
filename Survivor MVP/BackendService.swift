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

    /// Use 127.0.0.1 so simulator can reach backend (HTTP allowed via NSAllowsLocalNetworking in Info.plist).
    private static let defaultBaseURLValue = "http://127.0.0.1:8000"
    /// Fallback for environments where 127.0.0.1 is not reachable.
    private static let fallbackBaseURLValue = "http://localhost:8000"
    /// When testing on a physical device, set this to your Mac’s IP (e.g. "http://192.168.1.100:8000") so the device can reach the backend.
    static var deviceBaseURLOverride: String?

    init(baseURL: String? = nil) {
        let url = baseURL ?? Self.deviceBaseURLOverride ?? Self.defaultBaseURLValue
        self.baseURL = url.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.session = URLSession.shared
        self.decoder = JSONDecoder()
    }

    /// POST /api/chat — send user message, get AI response and session_id.
    /// Optionally include image (base64) and user_visible for vision and context.
    /// Tries baseURL then fallback (localhost). Returns nil on any failure (network, decode, 4xx/5xx).
    func sendMessage(sessionId: String?, text: String, imageBase64: String? = nil, userVisible: Bool? = nil) async -> (responseText: String, metadata: ChatResponsePayload.MetadataPayload?, sessionId: String)? {
        var urlsToTry = [baseURL, Self.fallbackBaseURLValue.trimmingCharacters(in: CharacterSet(charactersIn: "/"))]
        if let deviceURL = Self.deviceBaseURLOverride?.trimmingCharacters(in: CharacterSet(charactersIn: "/")), !urlsToTry.contains(deviceURL) {
            urlsToTry.append(deviceURL)
        }
        for base in urlsToTry {
            if let result = await performChat(baseURL: base, sessionId: sessionId, text: text, imageBase64: imageBase64, userVisible: userVisible) {
                return result
            }
        }
        return nil
    }

    private func performChat(baseURL: String, sessionId: String?, text: String, imageBase64: String? = nil, userVisible: Bool? = nil) async -> (responseText: String, metadata: ChatResponsePayload.MetadataPayload?, sessionId: String)? {
        guard let url = URL(string: "\(baseURL)/api/chat") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        var body: [String: Any?] = [
            "session_id": sessionId,
            "message": text,
        ]
        if let imageBase64 = imageBase64 {
            body["image_base64"] = imageBase64
        }
        if let userVisible = userVisible {
            body["user_visible"] = userVisible
        }
        let validBody = body.compactMapValues { $0 }
        guard let bodyData = try? JSONSerialization.data(withJSONObject: validBody) else { return nil }
        request.httpBody = bodyData
        request.timeoutInterval = 60

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
