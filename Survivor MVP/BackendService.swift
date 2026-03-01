//
//  BackendService.swift
//  Survivor MVP
//
//  API client: chat (with optional camera frame), TTS, STT, report.
//

import Foundation

// MARK: - Response types

struct ChatResponsePayload: Decodable {
    let response: ResponsePayload
    let session_id: String

    struct ResponsePayload: Decodable {
        let spoken_text: String
        let phase: String?
        let steps: [StepPayload]?
        let vitals: [String: Double]?
        let metadata: MetadataPayload?
    }

    struct StepPayload: Decodable {
        let instruction: String
        let image_url: String?
    }

    struct MetadataPayload: Decodable {
        let urgency: String?
        let diagnosis: String?
        let call_emergency: Bool?
        let confidence: Int?
        let key_findings: [String]?
        // Legacy fields
        let step: Int?
        let image_query: String?
        let category: String?
        let display_text: String?
    }
}

// MARK: - Swift value types returned to callers

struct StepResult {
    let instruction: String
    let imageURL: String?
}

struct ChatResult {
    let responseText: String
    let steps: [StepResult]
    let metadata: ChatResponsePayload.MetadataPayload?
    let phase: String
    let vitals: [String: Double]
    let sessionId: String
}

// MARK: - BackendService

@MainActor
final class BackendService {
    private let explicitBaseURL: String?
    private let session: URLSession
    private let decoder: JSONDecoder

    private static let defaultBaseURLValue = "http://127.0.0.1:8000"
    private static let fallbackBaseURLValue = "http://localhost:8000"
    static var deviceBaseURLOverride: String?

    /// Resolved at call time so that `deviceBaseURLOverride` set after init is picked up.
    private var baseURL: String {
        let url = explicitBaseURL ?? Self.deviceBaseURLOverride ?? Self.defaultBaseURLValue
        return url.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    init(baseURL: String? = nil) {
        self.explicitBaseURL = baseURL
        self.session = URLSession.shared
        self.decoder = JSONDecoder()
    }

    // MARK: - Chat

    /// Sends a user message (and optional JPEG camera frame) and returns the AI response with steps.
    func sendMessage(
        sessionId: String?,
        text: String,
        imageData: Data? = nil
    ) async -> ChatResult? {
        let urls = [baseURL, Self.fallbackBaseURLValue.trimmingCharacters(in: CharacterSet(charactersIn: "/"))]
        for base in urls {
            if let result = await performChat(baseURL: base, sessionId: sessionId, text: text, imageData: imageData) {
                return result
            }
        }
        return nil
    }

    private func performChat(
        baseURL: String,
        sessionId: String?,
        text: String,
        imageData: Data?
    ) async -> ChatResult? {
        guard let url = URL(string: "\(baseURL)/api/chat") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        var body: [String: Any] = ["message": text]
        if let sid = sessionId { body["session_id"] = sid }
        if let img = imageData { body["image_base64"] = img.base64EncodedString() }

        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        request.httpBody = bodyData

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return nil }
            let decoded = try decoder.decode(ChatResponsePayload.self, from: data)
            let steps = (decoded.response.steps ?? []).map {
                StepResult(instruction: $0.instruction, imageURL: $0.image_url)
            }
            return ChatResult(
                responseText: decoded.response.spoken_text,
                steps: steps,
                metadata: decoded.response.metadata,
                phase: decoded.response.phase ?? "questioning",
                vitals: decoded.response.vitals ?? [:],
                sessionId: decoded.session_id
            )
        } catch {
            return nil
        }
    }

    /// Analyze a camera frame passively — returns a text description of what the camera sees.
    /// Does NOT add to conversation history.
    func analyzeFrame(
        sessionId: String?,
        imageData: Data
    ) async -> String? {
        guard let url = URL(string: "\(baseURL)/api/analyze-frame") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        var body: [String: Any] = ["image_base64": imageData.base64EncodedString()]
        if let sid = sessionId { body["session_id"] = sid }

        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        request.httpBody = bodyData

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return nil }
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            return json?["description"] as? String
        } catch {
            return nil
        }
    }

    /// Sends an empty message to start a new session (used when AI greeted first; now session is created on first user message).
    func startSession() async -> (greeting: String, sessionId: String)? {
        let result = await sendMessage(sessionId: nil, text: "")
        guard let result else { return nil }
        return (result.responseText, result.sessionId)
    }

    // MARK: - TTS

    func requestTTS(text: String) async -> Data? {
        guard let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/api/tts?text=\(encoded)") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 60
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return nil }
            return data
        } catch { return nil }
    }

    // MARK: - STT

    func speechToText(audioData: Data) async -> String? {
        let urls = [baseURL, Self.fallbackBaseURLValue.trimmingCharacters(in: CharacterSet(charactersIn: "/"))]
        for base in urls {
            if let text = await performSTT(baseURL: base, audioData: audioData) { return text }
        }
        return nil
    }

    private func performSTT(baseURL: String, audioData: Data) async -> String? {
        guard let url = URL(string: "\(baseURL)/api/stt") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("audio/wav", forHTTPHeaderField: "Content-Type")
        request.httpBody = audioData
        request.timeoutInterval = 60
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return nil }
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            return json?["text"] as? String
        } catch { return nil }
    }

    // MARK: - Report

    struct ReportResult {
        let pdfData: Data
        let downloadURL: String?
    }

    func generateReport(sessionId: String) async -> ReportResult? {
        guard let url = URL(string: "\(baseURL)/api/report/\(sessionId)/generate") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return nil }
            let downloadURL = http.value(forHTTPHeaderField: "X-Download-URL")
            return ReportResult(pdfData: data, downloadURL: downloadURL)
        } catch { return nil }
    }
}
