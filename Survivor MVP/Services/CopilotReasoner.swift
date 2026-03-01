//
//  CopilotReasoner.swift
//  Survivor MVP
//
//  Protocol for LLM reasoning (e.g. Groq). Used by CrisisCopilotModel.
//

import Foundation

/// A single message in the conversation (role + text).
struct ReasonerMessage: Sendable {
    let role: String  // "user" | "assistant" | "system"
    let text: String
}

/// Protocol for the copilot's reasoning backend (e.g. Groq via FastAPI).
protocol CopilotReasoner: Sendable {
    /// Produce an assistant reply given system prompt, conversation history, and optional image.
    /// - Parameters:
    ///   - systemPrompt: System instructions for the model.
    ///   - conversation: Ordered messages (user/assistant).
    ///   - imageBase64JPEG: Optional base64-encoded JPEG for vision; nil for text-only.
    /// - Returns: Assistant reply text.
    func respond(systemPrompt: String, conversation: [ReasonerMessage], imageBase64JPEG: String?) async throws -> String
}
