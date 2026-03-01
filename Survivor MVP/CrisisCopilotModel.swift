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
    let id: UUID
    let role: ChatRole
    var text: String
    let timestamp: Date

    init(id: UUID? = nil, role: ChatRole, text: String, timestamp: Date = Date()) {
        self.id = id ?? UUID()
        self.role = role
        self.text = text
        self.timestamp = timestamp
    }

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

    // Voice + vision settings
    var audioOutEnabled: Bool
    var visionEnabled: Bool = true
    var handsFreePTT: Bool = false
    var elevenLabsVoiceId: String = ""

    // Listening / speaking state
    var isListening: Bool = false
    var liveTranscript: String { stt.partialTranscript }
    var isThinking: Bool = false
    var isSpeaking: Bool { tts.isSpeaking }

    // Banners (permission / errors)
    var bannerMessage: String?
    var bannerStyle: BannerView.BannerStyle = .info

    // Services (injectable; default to real implementations)
    var reasoner: GroqReasoner
    var tts: ElevenLabsTTSService
    var stt: AppleSpeechTranscriber

    private let greeting = "I'm Crisis Copilot. Tell me what's happening. If this is life-threatening, call emergency services now."
    private let wrapUp = "Session marked resolved. If you need to report again, start a new emergency."
    private static let thinkingPlaceholderText = "Thinking…"

    init(
        reasoner: GroqReasoner? = nil,
        tts: ElevenLabsTTSService? = nil,
        stt: AppleSpeechTranscriber? = nil
    ) {
        let ttsService = tts ?? ElevenLabsTTSService()
        self.reasoner = reasoner ?? GroqReasoner(backend: BackendService())
        self.tts = ttsService
        self.stt = stt ?? AppleSpeechTranscriber()
        self.audioOutEnabled = ttsService.isConfigured
        if !ttsService.isConfigured {
            self.bannerMessage = "Set ELEVENLABS_API_KEY to enable TTS"
            self.bannerStyle = .warning
        }
    }

    func startEmergency() {
        state = .active
        messages = []
        reasoner.resetSession()
        suggestedActions = Self.suggestedActions(for: scenario)
        messages.append(ChatMessage(role: .assistant, text: greeting, timestamp: Date()))
    }

    private let backendService = BackendService()

    func markResolved() {
        state = .resolved
        messages.append(ChatMessage(role: .assistant, text: wrapUp, timestamp: Date()))
        if let sid = reasoner.sessionId {
            Task { @MainActor in
                _ = await backendService.generateReport(sessionId: sid)
            }
        }
    }

    func reset() {
        state = .idle
        messages = []
        draftText = ""
        suggestedActions = []
        reasoner.resetSession()
    }

    func sendUserMessage(_ text: String, imageData: Data? = nil, userVisible: Bool? = nil) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        let imageBase64 = imageData.map { $0.base64EncodedString() }
        sendToLLM(text: t, imageBase64: imageBase64)
    }

    func sendToLLM(text: String, imageBase64: String? = nil) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        if state == .idle {
            state = .active
            suggestedActions = Self.suggestedActions(for: scenario)
        }
        messages.append(ChatMessage(role: .user, text: t, timestamp: Date()))
        draftText = ""
        let thinkingId = UUID()
        messages.append(ChatMessage(id: thinkingId, role: .assistant, text: Self.thinkingPlaceholderText, timestamp: Date()))
        isThinking = true
        Task { @MainActor in
            defer { isThinking = false }
            let conversation = messages.dropLast().map { msg in
                ReasonerMessage(role: msg.role == .user ? "user" : "assistant", text: msg.text)
            }
            do {
                let responseText = try await reasoner.respond(systemPrompt: "", conversation: conversation + [ReasonerMessage(role: "user", text: t)], imageBase64JPEG: imageBase64)
                if let idx = messages.firstIndex(where: { $0.id == thinkingId }) {
                    messages[idx].text = responseText
                }
                if audioOutEnabled {
                    try? await tts.speak(responseText)
                }
            } catch {
                let fallback = stubResponse(for: scenario)
                if let idx = messages.firstIndex(where: { $0.id == thinkingId }) {
                    messages[idx].text = fallback + " (Error: \(error.localizedDescription))"
                }
            }
        }
    }

    func startListening() {
        guard !isListening else { return }
        Task { @MainActor in
            let speechOK = await AppleSpeechTranscriber.requestAuthorization()
            guard speechOK else {
                bannerMessage = "Speech recognition denied. Enable in System Settings → Privacy & Security → Speech Recognition."
                bannerStyle = .warning
                return
            }
            let micOK = await AppleSpeechTranscriber.microphonePermissionGranted()
            guard micOK else {
                bannerMessage = "Microphone access denied. Enable in System Settings → Privacy & Security → Microphone."
                bannerStyle = .warning
                return
            }
            bannerMessage = nil
            stt.start()
            isListening = true
        }
    }

    func stopListeningAndSend() {
        guard isListening else { return }
        isListening = false
        Task { @MainActor in
            do {
                let transcript = try await stt.stop()
                let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { sendToLLM(text: trimmed, imageBase64: nil) }
            } catch {
                bannerMessage = "Speech recognition failed: \(error.localizedDescription)"
                bannerStyle = .error
            }
        }
    }

    func toggleListening() {
        if isListening { stopListeningAndSend() }
        else { startListening() }
    }

    func analyzeScene(imageBase64: String?) {
        let prompt = "Analyze the scene and give the next best step for the responder. Keep it short."
        if let img = imageBase64 {
            sendToLLM(text: prompt, imageBase64: img)
        } else {
            sendToLLM(text: "(I captured an image but your model may not support vision. Give generic guidance anyway.) " + prompt, imageBase64: nil)
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
