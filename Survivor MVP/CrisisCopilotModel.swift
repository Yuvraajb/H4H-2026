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

    // Live clinical state (updated with each AI response)
    var currentPhase: String = "questioning"       // "questioning" | "assessment" | "treatment"
    var currentUrgency: String = "low"             // "low" | "medium" | "high" | "critical"
    var callEmergency: Bool = false
    var currentDiagnosis: String? = nil
    var diagnosisConfidence: Int = 0
    var keyFindings: [String] = []
    var extractedVitals: [String: Double] = [:]    // hr, rr, spo2, gcs, sbp, temp
    var sessionStartTime: Date? = nil
    var isProcessing: Bool = false

    /// Set from ContentView so each user message can attach a camera frame.
    weak var cameraModel: CameraFeedModel?

    /// Set from ContentView — provides real-time body landmark context to the AI.
    weak var poseDetector: BodyPoseDetector?

    private let greeting = "Hey, I'm your personal doctor. What's going on — tell me exactly what happened."
    private let wrapUp = "Session resolved. Stay calm — you've done great. Start a new session if anything changes."

    private var sessionId: String?
    private let backendService = BackendService()

    func startEmergency() {
        state = .active
        messages = []
        sessionId = nil
        suggestedActions = []
        currentPhase = "questioning"
        currentUrgency = "low"
        callEmergency = false
        currentDiagnosis = nil
        diagnosisConfidence = 0
        keyFindings = []
        extractedVitals = [:]
        sessionStartTime = Date()
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
        currentPhase = "questioning"
        currentUrgency = "low"
        callEmergency = false
        currentDiagnosis = nil
        diagnosisConfidence = 0
        keyFindings = []
        extractedVitals = [:]
        sessionStartTime = nil
    }

    func sendUserMessage(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        if state == .idle { state = .active }
        messages.append(ChatMessage(role: .user, text: t))
        draftText = ""
        isProcessing = true

        // Capture camera frame to attach as visual context
        let imageData = cameraModel?.captureFrame()

        // Append detected body landmarks as extra context for the AI
        var messageText = t
        if let poseSummary = poseDetector?.landmarkSummary {
            messageText += "\n[Vision detection: \(poseSummary)]"
        }

        Task { @MainActor in
            defer { isProcessing = false }
            let result = await backendService.sendMessage(sessionId: sessionId, text: messageText, imageData: imageData)
            if let result {
                sessionId = result.sessionId

                // Update live clinical state
                currentPhase = result.phase
                if let meta = result.metadata {
                    if let u = meta.urgency { currentUrgency = u }
                    if let ce = meta.call_emergency { callEmergency = ce }
                    if let diag = meta.diagnosis { currentDiagnosis = diag }
                    if let conf = meta.confidence { diagnosisConfidence = conf }
                    if let findings = meta.key_findings { keyFindings = findings }
                }
                // Merge vitals (keep previously captured values if not updated)
                for (key, value) in result.vitals {
                    extractedVitals[key] = value
                }

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
