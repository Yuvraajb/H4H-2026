//
//  LeftRailView.swift
//  Survivor MVP
//
//  Crisis Copilot — left panel: scenario controls, status, camera toggle, quick actions.
//  CrisisCopilotPanelView: single overlay combining controls + chat + suggested actions.
//

import SwiftUI

// MARK: - Single left overlay (camera is full-window background; this panel contains all UI)
struct CrisisCopilotPanelView: View {
    @Environment(CrisisCopilotModel.self) private var model
    var cameraModel: CameraFeedModel
    @Binding var cameraPreviewEnabled: Bool
    @FocusState private var isComposerFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if let msg = model.bannerMessage, !msg.isEmpty {
                BannerView(message: msg, style: model.bannerStyle)
                    .padding(.bottom, 6)
            }
            panelHeader

            if model.isListening {
                HStack(spacing: 6) {
                    ProgressView().scaleEffect(0.8)
                    Text("Listening… \(model.liveTranscript)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.2), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .padding(.horizontal, 4)
                .padding(.bottom, 4)
            }
            if model.isThinking || model.isSpeaking {
                HStack(spacing: 6) {
                    if model.isThinking { ProgressView().scaleEffect(0.8) }
                    Text(model.isThinking ? "Thinking…" : "Speaking…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 4)
            }

            // Chat area: only the conversation (no fixed content)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(model.messages) { msg in
                            PanelMessageBubble(message: msg)
                                .id(msg.id)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .onChange(of: model.messages.count) { _, _ in
                    if let last = model.messages.last {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Composer: type here, AI responds
            panelComposerBar

            // Controls below chat (not inside the conversation)
            panelFooter
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var panelHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Text("Crisis Copilot")
                    .font(.title2)
                    .fontWeight(.bold)
                Text(panelStatusLabel)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(panelStatusColor.opacity(0.3), in: Capsule())
                Spacer(minLength: 0)
                Toggle("Camera", isOn: $cameraPreviewEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            HStack(spacing: 16) {
                Toggle("Audio out", isOn: Binding(get: { model.audioOutEnabled }, set: { model.audioOutEnabled = $0 }))
                    .toggleStyle(.switch)
                Toggle("Vision", isOn: Binding(get: { model.visionEnabled }, set: { model.visionEnabled = $0 }))
                    .toggleStyle(.switch)
                Toggle("Hands-free", isOn: Binding(get: { model.handsFreePTT }, set: { model.handsFreePTT = $0 }))
                    .toggleStyle(.switch)
            }
            .font(.caption)
            if cameraPreviewEnabled && cameraModel.status == .running {
                Text(cameraModel.personDetected ? "I can see you" : "Move into frame")
                    .font(.caption)
                    .foregroundStyle(cameraModel.personDetected ? .secondary : .tertiary)
            }
        }
        .padding(.bottom, 8)
    }

    private var panelFooter: some View {
        VStack(alignment: .leading, spacing: 10) {
            Group {
                switch model.state {
                case .idle:
                    Button(action: { model.startEmergency() }) {
                        Label("Start Emergency", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                case .active:
                    if model.visionEnabled {
                        Button(action: {
                            let base64 = cameraModel.captureJPEGBase64()
                            model.analyzeScene(imageBase64: base64)
                        }) {
                            Label("Analyze what I see", systemImage: "camera.viewfinder")
                        }
                        .buttonStyle(.bordered)
                    }
                    HStack(spacing: 8) {
                        Button("Simulate voice", action: { model.simulateVoiceInput() })
                            .buttonStyle(.bordered)
                        Button("Mark Resolved", action: { model.markResolved() })
                            .buttonStyle(.bordered)
                        Button("Clear", action: { model.clearChat() })
                            .buttonStyle(.bordered)
                    }
                case .resolved:
                    Button(action: { model.reset() }) {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }
            }
            if !model.suggestedActions.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(model.suggestedActions, id: \.self) { action in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("•")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(action)
                                .font(.caption)
                        }
                    }
                }
            }
            Text("This is a demo. If life-threatening, call emergency services.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.top, 12)
    }

    private var panelStatusLabel: String {
        switch model.state {
        case .idle: return "Idle"
        case .active: return "Active"
        case .resolved: return "Resolved"
        }
    }

    private var panelStatusColor: Color {
        switch model.state {
        case .idle: return .secondary
        case .active: return .green
        case .resolved: return .blue
        }
    }

    private var panelComposerBar: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField("Type a message…", text: Binding(get: { model.draftText }, set: { model.draftText = $0 }), axis: .vertical)
                .textFieldStyle(.plain)
                .padding(12)
                .lineLimit(1...6)
                .onSubmit { panelSendIfPossible() }
                .focused($isComposerFocused)
                .submitLabel(.send)

            PTTMicButton(
                isListening: model.isListening,
                handsFreeMode: model.handsFreePTT,
                onPress: { model.startListening() },
                onRelease: { model.stopListeningAndSend() },
                onTap: { model.toggleListening() }
            )

            Button(action: panelSendIfPossible) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .disabled(model.draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
        .background(.ultraThinMaterial.opacity(0.6), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func panelSendIfPossible() {
        let text = model.draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let imageData = cameraModel.captureCurrentFrame()
        let userVisible = cameraModel.personDetected
        model.sendUserMessage(text, imageData: imageData, userVisible: userVisible)
        model.draftText = ""
    }
}

private struct PanelMessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .user { Spacer(minLength: 24) }
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .font(.body)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(panelBubbleBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if message.role != .user { Spacer(minLength: 24) }
        }
    }

    private var panelBubbleBackground: some ShapeStyle {
        switch message.role {
        case .user:
            return AnyShapeStyle(Color.accentColor.opacity(0.25))
        case .assistant, .system:
            return AnyShapeStyle(.ultraThinMaterial)
        }
    }
}

struct LeftRailView: View {
    @Environment(CrisisCopilotModel.self) private var model
    @Binding var cameraPreviewEnabled: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                titleAndStatus
                cameraToggle
                primaryButton

                if model.state == .active {
                    quickActions
                }

                helperText
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(PanelBackgroundModifier())
    }

    private var titleAndStatus: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Crisis Copilot")
                .font(.title)
                .fontWeight(.bold)
            Text(statusLabel)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(statusColor.opacity(0.3), in: Capsule())
        }
    }

    private var statusLabel: String {
        switch model.state {
        case .idle: return "Idle"
        case .active: return "Active"
        case .resolved: return "Resolved"
        }
    }

    private var statusColor: Color {
        switch model.state {
        case .idle: return .secondary
        case .active: return .green
        case .resolved: return .blue
        }
    }

    private var cameraToggle: some View {
        Toggle("Camera preview", isOn: $cameraPreviewEnabled)
            .toggleStyle(.switch)
    }

    private var primaryButton: some View {
        Group {
            switch model.state {
            case .idle:
                Button(action: { model.startEmergency() }) {
                    Label("Start Emergency", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
            case .active:
                Button(action: { model.simulateVoiceInput() }) {
                    Label("Simulate Voice Input", systemImage: "mic.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
            case .resolved:
                Button(action: { model.reset() }) {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .controlSize(.large)
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick actions")
                .font(.headline)
            Button("Mark Resolved", action: { model.markResolved() })
                .buttonStyle(.bordered)
            Button("Clear Chat", action: { model.clearChat() })
                .buttonStyle(.bordered)
        }
    }

    private var helperText: some View {
        Text("This is a demo. If life-threatening, call emergency services.")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

#Preview {
    LeftRailView(cameraPreviewEnabled: .constant(true))
        .environment(CrisisCopilotModel())
        .frame(width: 320, height: 600)
}
