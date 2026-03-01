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
    /// - Returns: Response text and optional metadata (step, image_query, display_text for right-panel steps).
    func respond(systemPrompt: String, conversation: [ReasonerMessage], imageBase64JPEG: String?) async throws -> (responseText: String, metadata: ChatResponsePayload.MetadataPayload?)
}
