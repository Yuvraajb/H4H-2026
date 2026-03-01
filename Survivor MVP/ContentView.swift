//
//  ContentView.swift
//  Survivor MVP
//
//  Personal Doctor — voice-native macOS layout.
//  Left: live camera. Right: read-only transcript + full animated voice orb.
//

import SwiftUI

struct ContentView: View {
    @Environment(CrisisCopilotModel.self) private var model
    @State private var cameraModel = CameraFeedModel()
    @State private var voiceOrbModel = VoiceOrbModel()
    @State private var cameraPreviewEnabled = true

    var body: some View {
        ZStack(alignment: .trailing) {
            // Camera fills the full window
            cameraPane
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Floating frosted-glass sidebar
            VoicePanel(orbModel: voiceOrbModel)
                .frame(width: 320)
                .background(
                    .ultraThinMaterial.opacity(0.82),
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                )
                .shadow(color: .black.opacity(0.25), radius: 24, x: -4, y: 0)
                .padding(16)
        }
        .frame(minWidth: 700, minHeight: 500)
        .onAppear {
            cameraModel.start()
            voiceOrbModel.copilotModel = model
            model.cameraModel = cameraModel
            Task { await voiceOrbModel.autoGreet() }
        }
        .onDisappear { cameraModel.stop() }
    }

    @ViewBuilder
    private var cameraPane: some View {
        ZStack {
            Color.black.ignoresSafeArea()

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

            // Camera toggle — top-left so it doesn't overlap the panel
            VStack {
                HStack {
                    Toggle("", isOn: $cameraPreviewEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .padding(10)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                        .padding(12)
                    Spacer()
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

// MARK: - Voice panel (right side)

struct VoicePanel: View {
    @Environment(CrisisCopilotModel.self) private var model
    var orbModel: VoiceOrbModel

    // Orb animation state
    @State private var pulseUp = false
    @State private var ringExpand = false
    @State private var outerExpand = false
    @State private var thinkingStart: Date? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Personal Doctor")
                        .font(.headline)
                    Text("Tap the orb to speak")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Read-only conversation transcript
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        if model.messages.isEmpty {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.top, 48)
                        }
                        ForEach(model.messages) { msg in
                            TranscriptBubble(message: msg)
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

            Divider()

            // Full animated orb
            VStack(spacing: 18) {
                TimelineView(.animation(minimumInterval: 1.0 / 60, paused: orbModel.orbState != .thinking)) { tl in
                    let elapsed = thinkingStart.map { tl.date.timeIntervalSince($0) } ?? 0
                    ZStack {
                        // Outer ring
                        Circle()
                            .stroke(outerRingColor, lineWidth: 1.5)
                            .frame(width: 150, height: 150)
                            .scaleEffect(outerExpand ? 1.06 : 1.0)
                            .rotationEffect(.degrees(
                                orbModel.orbState == .thinking
                                ? (elapsed * -225).truncatingRemainder(dividingBy: 360)
                                : 0
                            ))
                            .opacity(orbModel.orbState != .idle ? 1 : 0)

                        // Mid ring
                        Circle()
                            .stroke(midRingColor, lineWidth: 1.5)
                            .frame(width: 124, height: 124)
                            .scaleEffect(ringExpand ? 1.08 : 1.0)
                            .rotationEffect(.degrees(
                                orbModel.orbState == .thinking
                                ? (elapsed * 360).truncatingRemainder(dividingBy: 360)
                                : 0
                            ))
                            .opacity(orbModel.orbState != .idle ? 1 : 0)

                        // Core orb
                        Circle()
                            .fill(orbGradient)
                            .frame(width: 100, height: 100)
                            .overlay(
                                Circle().fill(LinearGradient(
                                    colors: [.white.opacity(0.06), .clear],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ))
                            )
                            .shadow(color: glowColor.opacity(0.5), radius: 20)
                            .shadow(color: glowColor.opacity(0.15), radius: 50)
                            .scaleEffect(pulseUp ? pulseTarget : 1.0)
                    }
                }
                .frame(width: 160, height: 160)
                .onTapGesture { orbModel.handleTap() }

                Text(orbModel.statusText)
                    .font(.caption)
                    .tracking(1)
                    .foregroundStyle(.secondary)
                    .animation(.default, value: orbModel.statusText)

                if let err = orbModel.errorText {
                    Text(err)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity)
            .onChange(of: orbModel.orbState) { _, newState in
                withAnimation(.none) {
                    pulseUp = false
                    ringExpand = false
                    outerExpand = false
                }
                if newState == .thinking { thinkingStart = Date() }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(16))
                    triggerAnimations(for: newState)
                }
            }
            .onAppear { triggerAnimations(for: .idle) }
        }
        .background(.background)
    }

    // MARK: - Animations

    private var pulseTarget: CGFloat {
        switch orbModel.orbState {
        case .idle:      return 1.04
        case .listening: return 1.06
        case .speaking:  return 1.05
        case .thinking:  return 1.0
        }
    }

    private var animDuration: Double {
        switch orbModel.orbState {
        case .idle:      return 3.5
        case .listening: return 0.9
        case .speaking:  return 1.6
        case .thinking:  return 1.0
        }
    }

    private func triggerAnimations(for state: VoiceOrbModel.OrbState) {
        let anim = Animation.easeInOut(duration: animDuration).repeatForever(autoreverses: true)
        let delay = Animation.easeInOut(duration: animDuration).delay(0.2).repeatForever(autoreverses: true)
        switch state {
        case .idle:
            withAnimation(anim) { pulseUp = true }
        case .listening:
            withAnimation(anim)  { pulseUp = true; ringExpand = true }
            withAnimation(delay) { outerExpand = true }
        case .thinking:
            break // TimelineView handles rotation
        case .speaking:
            withAnimation(anim)  { pulseUp = true; ringExpand = true }
            withAnimation(delay) { outerExpand = true }
        }
    }

    // MARK: - Colors

    private var orbGradient: RadialGradient {
        switch orbModel.orbState {
        case .idle:
            return RadialGradient(colors: [Color(red: 0.23, green: 0.23, blue: 0.42), Color(red: 0.10, green: 0.10, blue: 0.25)],
                                  center: .init(x: 0.38, y: 0.36), startRadius: 0, endRadius: 50)
        case .listening:
            return RadialGradient(colors: [Color(red: 0.48, green: 0.10, blue: 0.16), Color(red: 0.24, green: 0, blue: 0.08)],
                                  center: .init(x: 0.38, y: 0.36), startRadius: 0, endRadius: 50)
        case .thinking:
            return RadialGradient(colors: [Color(red: 0.35, green: 0.29, blue: 0.06), Color(red: 0.16, green: 0.13, blue: 0)],
                                  center: .init(x: 0.38, y: 0.36), startRadius: 0, endRadius: 50)
        case .speaking:
            return RadialGradient(colors: [Color(red: 0.06, green: 0.29, blue: 0.19), Color(red: 0, green: 0.15, blue: 0.09)],
                                  center: .init(x: 0.38, y: 0.36), startRadius: 0, endRadius: 50)
        }
    }

    private var glowColor: Color {
        switch orbModel.orbState {
        case .idle:      return Color(red: 0.42, green: 0.39, blue: 1.0)
        case .listening: return Color(red: 1.0,  green: 0.30, blue: 0.42)
        case .thinking:  return Color(red: 0.98, green: 0.78, blue: 0.20)
        case .speaking:  return Color(red: 0.30, green: 1.0,  blue: 0.57)
        }
    }

    private var midRingColor: Color {
        switch orbModel.orbState {
        case .idle:      return .clear
        case .listening: return Color(red: 1.0,  green: 0.30, blue: 0.42).opacity(0.35)
        case .thinking:  return Color(red: 0.98, green: 0.78, blue: 0.20).opacity(0.50)
        case .speaking:  return Color(red: 0.30, green: 1.0,  blue: 0.57).opacity(0.30)
        }
    }

    private var outerRingColor: Color {
        switch orbModel.orbState {
        case .idle:      return .clear
        case .listening: return Color(red: 1.0,  green: 0.30, blue: 0.42).opacity(0.15)
        case .thinking:  return Color(red: 0.98, green: 0.78, blue: 0.20).opacity(0.18)
        case .speaking:  return Color(red: 0.30, green: 1.0,  blue: 0.57).opacity(0.12)
        }
    }
}

// MARK: - Transcript bubble (read-only, step-aware)

private struct TranscriptBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .user { Spacer(minLength: 32) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
                // Spoken text
                if !message.text.isEmpty {
                    Text(message.text)
                        .font(.callout)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(bubbleBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                // Treatment steps with Wikipedia images
                if !message.steps.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(message.steps.enumerated()), id: \.element.id) { idx, step in
                            StepCard(number: idx + 1, step: step)
                        }
                    }
                    .padding(.top, 4)
                }

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

private struct StepCard: View {
    let number: Int
    let step: ChatStep

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                // Number badge
                Text("\(number)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(Color.accentColor, in: Circle())

                Text(step.instruction)
                    .font(.callout)
                    .fontWeight(.medium)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Wikipedia illustration
            if let url = step.imageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: 240, maxHeight: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    case .failure:
                        EmptyView()
                    case .empty:
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.primary.opacity(0.05))
                            .frame(width: 240, height: 120)
                            .overlay(ProgressView().scaleEffect(0.6))
                    @unknown default:
                        EmptyView()
                    }
                }
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview("Personal Doctor") {
    ContentView()
        .environment(AppModel())
        .environment(CrisisCopilotModel())
        .frame(width: 960, height: 620)
}
