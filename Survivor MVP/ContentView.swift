//
//  ContentView.swift
//  Survivor MVP
//
//  Personal Doctor — macOS two-panel layout.
//  Left: live camera preview. Right: chat + inline voice orb + text composer.
//

import SwiftUI

struct ContentView: View {
    @Environment(CrisisCopilotModel.self) private var model
    @State private var cameraModel = CameraFeedModel()
    @State private var voiceOrbModel = VoiceOrbModel()
    @State private var cameraPreviewEnabled = true

    var body: some View {
        HStack(spacing: 0) {
            cameraPane
                .frame(minWidth: 400, maxWidth: .infinity)

            Divider()

            PersonalDoctorPanel(voiceOrbModel: voiceOrbModel)
                .frame(width: 380)
        }
        .frame(minWidth: 900, minHeight: 620)
        .onAppear {
            cameraModel.start()
            voiceOrbModel.copilotModel = model
        }
        .onDisappear {
            cameraModel.stop()
        }
    }

    @ViewBuilder
    private var cameraPane: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            if cameraPreviewEnabled, cameraModel.status == .running, let session = cameraModel.session {
                CameraPreview(session: session)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text(cameraStatusText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            // Camera toggle — top-right corner
            VStack {
                HStack {
                    Spacer()
                    Toggle("", isOn: $cameraPreviewEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .padding(10)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                        .padding(12)
                }
                Spacer()
            }
        }
        .onChange(of: cameraPreviewEnabled) { _, enabled in
            if enabled { cameraModel.start() } else { cameraModel.stop() }
        }
    }

    private var cameraStatusText: String {
        switch cameraModel.status {
        case .idle:                 return "Starting camera…"
        case .requestingPermission: return "Requesting camera permission…"
        case .unauthorized:         return "Camera permission denied."
        case .unavailable:          return "No camera available."
        case .running:              return ""
        case .failed(let msg):      return msg
        }
    }
}

// MARK: - Right panel

struct PersonalDoctorPanel: View {
    @Environment(CrisisCopilotModel.self) private var model
    var voiceOrbModel: VoiceOrbModel
    @FocusState private var composerFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            chatArea
            Divider()
            CompactVoiceOrb(model: voiceOrbModel)
                .padding(.vertical, 10)
            Divider()
            composerBar
        }
        .background(.background)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Personal Doctor")
                    .font(.headline)
                Text("Groq · ElevenLabs voice")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var chatArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if model.messages.isEmpty {
                        Text("Tap the orb to speak, or type below.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 48)
                    }
                    ForEach(model.messages) { msg in
                        MessageBubble(message: msg)
                            .id(msg.id)
                    }
                }
                .padding(12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: model.messages.count) { _, _ in
                if let last = model.messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var composerBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Type a message…", text: Binding(
                get: { model.draftText },
                set: { model.draftText = $0 }
            ), axis: .vertical)
            .textFieldStyle(.plain)
            .padding(10)
            .lineLimit(1...5)
            .onSubmit { sendText() }
            .focused($composerFocused)

            Button(action: sendText) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .disabled(model.draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func sendText() {
        let text = model.draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        model.sendUserMessage(text)
    }
}

// MARK: - Compact inline voice orb

private struct CompactVoiceOrb: View {
    var model: VoiceOrbModel
    @State private var pulseUp = false

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(orbGradient)
                    .frame(width: 46, height: 46)
                    .shadow(color: glowColor.opacity(0.5), radius: 10)
                    .scaleEffect(pulseUp ? pulseTarget : 1.0)
                if model.orbState == .thinking {
                    ProgressView()
                        .scaleEffect(0.5)
                        .tint(.white)
                }
            }
            .onTapGesture { model.handleTap() }

            VStack(alignment: .leading, spacing: 2) {
                Text(model.statusText)
                    .font(.caption)
                    .fontWeight(.medium)
                    .animation(.default, value: model.statusText)
                if let err = model.errorText {
                    Text(err)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .onChange(of: model.orbState) { _, _ in
            withAnimation(.none) { pulseUp = false }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(16))
                withAnimation(pulseAnim) { pulseUp = true }
            }
        }
        .onAppear {
            withAnimation(pulseAnim) { pulseUp = true }
        }
    }

    private var pulseAnim: Animation {
        .easeInOut(duration: animDuration).repeatForever(autoreverses: true)
    }

    private var pulseTarget: CGFloat {
        switch model.orbState {
        case .idle:      return 1.06
        case .listening: return 1.14
        case .speaking:  return 1.10
        case .thinking:  return 1.0
        }
    }

    private var animDuration: Double {
        switch model.orbState {
        case .idle:      return 3.5
        case .listening: return 0.7
        case .speaking:  return 1.4
        case .thinking:  return 1.0
        }
    }

    private var orbGradient: RadialGradient {
        switch model.orbState {
        case .idle:
            return RadialGradient(colors: [Color(red: 0.23, green: 0.23, blue: 0.42), Color(red: 0.10, green: 0.10, blue: 0.25)],
                                  center: .init(x: 0.38, y: 0.36), startRadius: 0, endRadius: 23)
        case .listening:
            return RadialGradient(colors: [Color(red: 0.48, green: 0.10, blue: 0.16), Color(red: 0.24, green: 0, blue: 0.08)],
                                  center: .init(x: 0.38, y: 0.36), startRadius: 0, endRadius: 23)
        case .thinking:
            return RadialGradient(colors: [Color(red: 0.35, green: 0.29, blue: 0.06), Color(red: 0.16, green: 0.13, blue: 0)],
                                  center: .init(x: 0.38, y: 0.36), startRadius: 0, endRadius: 23)
        case .speaking:
            return RadialGradient(colors: [Color(red: 0.06, green: 0.29, blue: 0.19), Color(red: 0, green: 0.15, blue: 0.09)],
                                  center: .init(x: 0.38, y: 0.36), startRadius: 0, endRadius: 23)
        }
    }

    private var glowColor: Color {
        switch model.orbState {
        case .idle:      return Color(red: 0.42, green: 0.39, blue: 1.0)
        case .listening: return Color(red: 1.0,  green: 0.30, blue: 0.42)
        case .thinking:  return Color(red: 0.98, green: 0.78, blue: 0.20)
        case .speaking:  return Color(red: 0.30, green: 1.0,  blue: 0.57)
        }
    }
}

// MARK: - Message bubble

private struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .user { Spacer(minLength: 32) }
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 3) {
                Text(message.text)
                    .font(.body)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(bubbleBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if message.role != .user { Spacer(minLength: 32) }
        }
    }

    private var bubbleBackground: some ShapeStyle {
        message.role == .user
            ? AnyShapeStyle(Color.accentColor.opacity(0.22))
            : AnyShapeStyle(Color.primary.opacity(0.06))
    }
}

#Preview("Personal Doctor") {
    ContentView()
        .environment(AppModel())
        .environment(CrisisCopilotModel())
        .frame(width: 1000, height: 640)
}
