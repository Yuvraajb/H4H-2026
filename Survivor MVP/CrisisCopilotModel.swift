//
//  CrisisCopilotModel.swift
//  Survivor MVP
//
//  Crisis Copilot: app state, scenario, chat messages, stub responses.
//

import SwiftUI

enum CrisisAppState: String, CaseIterable {
    case idle
    case active
    case resolved
}

enum CrisisScenario: String, CaseIterable {
    case medical = "Medical"
    case fire = "Fire"
    case earthquake = "Earthquake"
    case suspicious = "Suspicious Activity"
    case other = "Other"
}

enum InputMode: String, CaseIterable {
    case voice
    case touch
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: ChatRole
    let text: String
    let timestamp: Date

    enum ChatRole {
        case user
        case assistant
        case system
    }
}

@MainActor
@Observable
class CrisisCopilotModel {
    var state: CrisisAppState = .idle
    var scenario: CrisisScenario = .medical
    var inputMode: InputMode = .voice
    var messages: [ChatMessage] = []
    var draftText: String = ""
    var suggestedActions: [String] = []

    private let greeting = "I'm Crisis Copilot. Tell me what's happening. If this is life-threatening, call emergency services now."
    private let wrapUp = "Session marked resolved. If you need to report again, start a new emergency."

    private var sessionId: String?
    private let backendService = BackendService()

    func startEmergency() {
        state = .active
        messages = []
        sessionId = nil
        suggestedActions = Self.suggestedActions(for: scenario)
        messages.append(ChatMessage(role: .assistant, text: greeting, timestamp: Date()))

        Task { @MainActor in
            if let result = await backendService.startSession() {
                sessionId = result.sessionId
            }
        }
    }

    func markResolved() {
        state = .resolved
        messages.append(ChatMessage(role: .assistant, text: wrapUp, timestamp: Date()))
        if let sid = sessionId {
            Task { @MainActor in
                _ = await backendService.generateReport(sessionId: sid)
                // Optionally save or show report; for now we just trigger generation
            }
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
        messages.append(ChatMessage(role: .user, text: t, timestamp: Date()))

        Task { @MainActor in
            let result = await backendService.sendMessage(sessionId: sessionId, text: t)
            if let result {
                sessionId = result.sessionId
                messages.append(ChatMessage(role: .assistant, text: result.responseText, timestamp: Date()))
            } else {
                messages.append(ChatMessage(role: .assistant, text: stubResponse(for: scenario), timestamp: Date()))
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
            messages.append(ChatMessage(role: .assistant, text: greeting, timestamp: Date()))
        }
    }

    private func stubResponse(for s: CrisisScenario) -> String {
        switch s {
        case .medical:
            return "Understood. Is the person responsive and breathing normally?"
        case .fire:
            return "Are you indoors or outdoors? Do you see flames or smoke?"
        case .earthquake:
            return "Are you in a safe location away from glass? Any injuries?"
        case .suspicious:
            return "Where are you? Can you get to a safe place without approaching the person?"
        case .other:
            return "Tell me a bit more. What do you see or hear right now?"
        }
    }

    private static func suggestedActions(for scenario: CrisisScenario) -> [String] {
        switch scenario {
        case .medical:
            return ["Check responsiveness", "Check breathing", "Call emergency services if not breathing"]
        case .fire:
            return ["Evacuate if unsafe", "Avoid smoke", "Call emergency services"]
        case .earthquake:
            return ["Drop, cover, hold on", "Check injuries", "Watch for aftershocks"]
        case .suspicious:
            return ["Move to safety", "Do not confront", "Call authorities"]
        case .other:
            return ["Stay calm", "Call emergency services if needed"]
        }
    }
}
