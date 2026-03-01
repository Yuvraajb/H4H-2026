//
//  GroqReasoner.swift
//  Survivor MVP
//
//  CopilotReasoner implementation using the FastAPI backend (Groq LLM).
//

import Foundation

@MainActor
final class GroqReasoner: CopilotReasoner {
    private let backend: BackendService
    private(set) var sessionId: String?

    init(backend: BackendService) {
        self.backend = backend
    }

    func respond(systemPrompt: String, conversation: [ReasonerMessage], imageBase64JPEG: String?) async throws -> (responseText: String, metadata: ChatResponsePayload.MetadataPayload?) {
        guard let last = conversation.last, last.role == "user" else {
            throw ReasonerError.noUserMessage
        }
        let result = await backend.sendMessage(
            sessionId: sessionId,
            text: last.text,
            imageBase64: imageBase64JPEG,
            userVisible: nil
        )
        guard let result else {
            throw ReasonerError.backendUnavailable
        }
        sessionId = result.sessionId
        return (result.responseText, result.metadata)
    }

    func resetSession() {
        sessionId = nil
    }

    enum ReasonerError: Error {
        case noUserMessage
        case backendUnavailable
    }
}
