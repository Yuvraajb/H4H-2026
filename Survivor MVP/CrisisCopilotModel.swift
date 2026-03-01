//
//  CrisisCopilotModel.swift
//  Survivor MVP
//
//  Survivor — conversation state, messages, and backend integration.
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
    var isGeneratingReport: Bool = false
    var reportData: Data? = nil
    var reportDownloadURL: String? = nil
    var actionResult: String? = nil           // Result from action verification (pulse BPM, CPR confirmed, etc.)

    /// Set from ContentView so each user message can attach a camera frame.
    weak var cameraModel: CameraFeedModel?

    /// Set from ContentView — provides real-time body landmark context to the AI.
    weak var poseDetector: BodyPoseDetector?
    private let wrapUp = "Session resolved. Stay calm — you've done great. Start a new session if anything changes."

    private var sessionId: String?
    private let backendService = BackendService()

    /// Start session without speaking — user speaks first.
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
        actionResult = nil
    }

    func markResolved() {
        state = .resolved
        messages.append(ChatMessage(role: .assistant, text: wrapUp))
        generateReport()
    }

    func generateReport() {
        guard let sid = sessionId, !isGeneratingReport else { return }
        isGeneratingReport = true
        Task { @MainActor in
            defer { isGeneratingReport = false }
            if let result = await backendService.generateReport(sessionId: sid) {
                reportData = result.pdfData
                reportDownloadURL = result.downloadURL
            }
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
        isGeneratingReport = false
        reportData = nil
        reportDownloadURL = nil
        actionResult = nil
    }

    func sendUserMessage(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        if state == .idle { state = .active }
        messages.append(ChatMessage(role: .user, text: t))
        draftText = ""
        isProcessing = true

        // Capture a fresh camera frame + attach visual context
        let imageData = cameraModel?.captureFrame()
        let visualCtx = latestVisualContext
        latestVisualContext = nil  // consumed

        var messageText = t
        if let ctx = visualCtx {
            messageText = "[Camera observation: \(ctx)] \(messageText)"
        }
        if let poseSummary = poseDetector?.landmarkSummary {
            messageText += "\n[Vision detection: \(poseSummary)]"
        }
        if let result = actionResult {
            messageText += "\n[Action verified: \(result)]"
            actionResult = nil  // consumed
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

    /// Latest visual context from the camera — silently stored, used on next user message.
    private var latestVisualContext: String?

    /// Passively capture a camera frame and send it for visual analysis.
    /// Does NOT add anything to the chat — just updates internal visual context
    /// so the next user message benefits from what the camera sees.
    func sendVisualCheckIn() {
        guard state == .active, !isProcessing else { return }
        guard let imageData = cameraModel?.captureFrame() else { return }

        Task { @MainActor in
            let description = await backendService.analyzeFrame(
                sessionId: sessionId,
                imageData: imageData
            )
            if let description, !description.isEmpty {
                latestVisualContext = description
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
    }
}
