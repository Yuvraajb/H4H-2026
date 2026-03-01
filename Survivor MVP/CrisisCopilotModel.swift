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

/// Protocol buttons in the Protocols panel (Dispatch / Live Guidance reference).
enum EmergencyProtocol: String, CaseIterable {
    case cpr = "CPR"
    case choking = "Choking"
    case bleeding = "Bleeding"
    case shock = "Shock"
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
    /// When set, show as "ACTION REQUIRED" style (bold label + left border) in Dispatch.
    var actionRequiredTitle: String? = nil

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
    var selectedProtocol: EmergencyProtocol = .cpr
    var inputMode: InputMode = .voice
    var messages: [ChatMessage] = []
    var draftText: String = ""
    var suggestedActions: [String] = []

    /// When non-nil, Dispatch shows "Connected • MM:SS" using this start date.
    var dispatchConnectedSince: Date? = nil

    /// Stub data for Location & ETA panel.
    struct LocationStub {
        var nearestAEDName: String
        var nearestAEDDetail: String
        var nearestAEDDistance: String
        var ambulanceETAMinutes: Int
        var ambulanceUnit: String
    }
    var locationStub: LocationStub = LocationStub(
        nearestAEDName: "Central Library",
        nearestAEDDetail: "Floor 1, Main Lobby",
        nearestAEDDistance: "0.2 miles • 3 min walk",
        ambulanceETAMinutes: 4,
        ambulanceUnit: "Unit 402 en route"
    )

    private let greeting = "I'm Crisis Copilot. Tell me what's happening. If this is life-threatening, call emergency services now."
    private let wrapUp = "Session marked resolved. If you need to report again, start a new emergency."

    func startEmergency() {
        state = .active
        dispatchConnectedSince = Date()
        messages = []
        messages.append(ChatMessage(role: .assistant, text: greeting, timestamp: Date()))
        suggestedActions = Self.suggestedActions(for: scenario)
    }

    func markResolved() {
        state = .resolved
        messages.append(ChatMessage(role: .assistant, text: wrapUp, timestamp: Date()))
    }

    func reset() {
        state = .idle
        dispatchConnectedSince = nil
        messages = []
        draftText = ""
        suggestedActions = []
    }

    func sendUserMessage(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        messages.append(ChatMessage(role: .user, text: t, timestamp: Date()))
        let stub = stubResponse(for: scenario)
        messages.append(ChatMessage(role: .assistant, text: stub, timestamp: Date()))
    }

    /// Add a message that shows as "ACTION REQUIRED" in Dispatch.
    func sendActionRequiredMessage(_ text: String) {
        var msg = ChatMessage(role: .assistant, text: text, timestamp: Date(), actionRequiredTitle: "ACTION REQUIRED")
        messages.append(msg)
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

    /// Formatted "Connected • MM:SS" for Dispatch header; returns nil if not connected.
    var dispatchConnectionDuration: String? {
        guard let since = dispatchConnectedSince else { return nil }
        let elapsed = Int(Date().timeIntervalSince(since))
        let m = elapsed / 60
        let s = elapsed % 60
        return String(format: "%02d:%02d", m, s)
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
