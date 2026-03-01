//
//  CrisisCopilotModel.swift
//  Survivor MVP
//
//  Personal Doctor — conversation state, messages, and backend integration.
//

import SwiftUI

enum CrisisAppState: String, CaseIterable { case idle, active, resolved }
enum CrisisScenario: String, CaseIterable {
    case medical = "Medical"; case fire = "Fire"
    case earthquake = "Earthquake"; case suspicious = "Suspicious Activity"; case other = "Other"
}
enum InputMode: String, CaseIterable { case voice, touch }

// MARK: - Data types

struct ChatStep: Identifiable {
    let id = UUID()
    let instruction: String
    let imageURL: URL?
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: ChatRole
    let text: String          // spoken text (also shown in chat)
    let steps: [ChatStep]     // empty for Q&A turns; populated during treatment phase
    let timestamp: Date

    init(role: ChatRole, text: String, steps: [ChatStep] = [], timestamp: Date = Date()) {
        self.role = role
        self.text = text
        self.steps = steps
        self.timestamp = timestamp
    }

    enum ChatRole { case user, assistant, system }
}

// MARK: - Model

@MainActor
@Observable
class CrisisCopilotModel {
    var state: CrisisAppState = .idle
    var scenario: CrisisScenario = .medical
    var inputMode: InputMode = .voice
    var messages: [ChatMessage] = []
    var draftText: String = ""
    var suggestedActions: [String] = []

    /// Set from ContentView so each user message can attach a camera frame.
    weak var cameraModel: CameraFeedModel?

    private let greeting = "Hey! I'm your personal doctor. What's going on — tell me what's happening and I'll help you through it."
    private let wrapUp = "Session marked resolved. If you need to report again, start a new emergency."

    private var sessionId: String?
    private let backendService = BackendService()

    func startEmergency() {
        state = .active
        messages = []
        sessionId = nil
        suggestedActions = []
        messages.append(ChatMessage(role: .assistant, text: greeting))

        Task { @MainActor in
            if let result = await backendService.startSession() {
                sessionId = result.sessionId
            }
        }
    }

    func markResolved() {
        state = .resolved
        messages.append(ChatMessage(role: .assistant, text: wrapUp))
        if let sid = sessionId {
            Task { @MainActor in _ = await backendService.generateReport(sessionId: sid) }
        }
    }

    func reset() {
        state = .idle
        messages = []
        draftText = ""
        suggestedActions = []
        sessionId = nil
    }

    func sendUserMessage(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        if state == .idle { state = .active }
        messages.append(ChatMessage(role: .user, text: t))
        draftText = ""

        // Capture camera frame to attach as visual context
        let imageData = cameraModel?.captureFrame()

        Task { @MainActor in
            let result = await backendService.sendMessage(sessionId: sessionId, text: t, imageData: imageData)
            if let result {
                sessionId = result.sessionId
                let msg = ChatMessage(
                    role: .assistant,
                    text: result.responseText,
                    steps: result.steps.compactMap { step in
                        ChatStep(instruction: step.instruction, imageURL: step.imageURL.flatMap(URL.init))
                    }
                )
                messages.append(msg)
            } else {
                let fallback = "I'm having trouble reaching the AI. Make sure the backend is running at port 8000."
                messages.append(ChatMessage(role: .assistant, text: fallback))
            }
        }
    }

    func simulateVoiceInput() {
        let canned: String
        switch scenario {
        case .medical: canned = "Someone collapsed. I don't know if they're breathing."
        case .fire: canned = "I see smoke in the building."
        case .earthquake: canned = "We felt a strong shake. Some things fell."
        case .suspicious: canned = "There's someone acting strangely outside."
        case .other: canned = "I need to report an emergency."
        }
        sendUserMessage(canned)
    }

    func clearChat() {
        messages = []
        if state == .active {
            messages.append(ChatMessage(role: .assistant, text: greeting))
        }
    }
}
