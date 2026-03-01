import SwiftUI

struct VoiceOrbView: View {
    @Environment(CrisisCopilotModel.self) private var copilotModel
    @State private var model = VoiceOrbModel()

    // Animation state
    @State private var pulseUp = false
    @State private var ringExpand = false
    @State private var outerExpand = false
    @State private var thinkingStart: Date? = nil

    var body: some View {
        VStack(spacing: 24) {
            Text("VOICE")
                .font(.caption)
                .fontWeight(.bold)
                .tracking(4)
                .foregroundStyle(.secondary)

            TimelineView(.animation(minimumInterval: 1.0 / 60, paused: model.orbState != .thinking)) { tl in
                let elapsed = thinkingStart.map { tl.date.timeIntervalSince($0) } ?? 0
                ZStack {
                    // Outer ring
                    Circle()
                        .stroke(outerRingColor, lineWidth: 1.5)
                        .frame(width: 150, height: 150)
                        .scaleEffect(outerExpand ? 1.06 : 1.0)
                        .rotationEffect(.degrees(
                            model.orbState == .thinking
                            ? (elapsed * -225).truncatingRemainder(dividingBy: 360)
                            : 0
                        ))
                        .opacity(model.orbState != .idle ? 1 : 0)

                    // Mid ring
                    Circle()
                        .stroke(midRingColor, lineWidth: 1.5)
                        .frame(width: 124, height: 124)
                        .scaleEffect(ringExpand ? 1.08 : 1.0)
                        .rotationEffect(.degrees(
                            model.orbState == .thinking
                            ? (elapsed * 360).truncatingRemainder(dividingBy: 360)
                            : 0
                        ))
                        .opacity(model.orbState != .idle ? 1 : 0)

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
            .onTapGesture { model.handleTap() }

            Text(model.statusText)
                .font(.caption)
                .tracking(1)
                .foregroundStyle(.secondary)
                .animation(.default, value: model.statusText)

            if let err = model.errorText {
                Text(err)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding(32)
        .frame(width: 280)
        .onAppear {
            model.copilotModel = copilotModel
            triggerAnimations(for: .idle)
        }
        .onChange(of: model.orbState) { _, newState in
            withAnimation(.none) {
                pulseUp = false
                ringExpand = false
                outerExpand = false
            }
            if newState == .thinking { thinkingStart = Date() }
            // Small delay lets the reset propagate before starting new anim
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(16))
                triggerAnimations(for: newState)
            }
        }
    }

    // MARK: - Animations

    var pulseTarget: CGFloat {
        switch model.orbState {
        case .idle: return 1.04
        case .listening: return 1.06
        case .speaking: return 1.05
        case .thinking: return 1.0
        }
    }

    var animDuration: Double {
        switch model.orbState {
        case .idle: return 3.5
        case .listening: return 0.9
        case .speaking: return 1.6
        case .thinking: return 1.0
        }
    }

    func triggerAnimations(for state: VoiceOrbModel.OrbState) {
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

    var orbGradient: RadialGradient {
        switch model.orbState {
        case .idle:
            return RadialGradient(
                colors: [Color(red: 0.23, green: 0.23, blue: 0.42), Color(red: 0.10, green: 0.10, blue: 0.25)],
                center: .init(x: 0.38, y: 0.36), startRadius: 0, endRadius: 50)
        case .listening:
            return RadialGradient(
                colors: [Color(red: 0.48, green: 0.10, blue: 0.16), Color(red: 0.24, green: 0, blue: 0.08)],
                center: .init(x: 0.38, y: 0.36), startRadius: 0, endRadius: 50)
        case .thinking:
            return RadialGradient(
                colors: [Color(red: 0.35, green: 0.29, blue: 0.06), Color(red: 0.16, green: 0.13, blue: 0)],
                center: .init(x: 0.38, y: 0.36), startRadius: 0, endRadius: 50)
        case .speaking:
            return RadialGradient(
                colors: [Color(red: 0.06, green: 0.29, blue: 0.19), Color(red: 0, green: 0.15, blue: 0.09)],
                center: .init(x: 0.38, y: 0.36), startRadius: 0, endRadius: 50)
        }
    }

    var glowColor: Color {
        switch model.orbState {
        case .idle:      return Color(red: 0.42, green: 0.39, blue: 1.0)
        case .listening: return Color(red: 1.0,  green: 0.30, blue: 0.42)
        case .thinking:  return Color(red: 0.98, green: 0.78, blue: 0.20)
        case .speaking:  return Color(red: 0.30, green: 1.0,  blue: 0.57)
        }
    }

    var midRingColor: Color {
        switch model.orbState {
        case .idle:      return .clear
        case .listening: return Color(red: 1.0,  green: 0.30, blue: 0.42).opacity(0.35)
        case .thinking:  return Color(red: 0.98, green: 0.78, blue: 0.20).opacity(0.50)
        case .speaking:  return Color(red: 0.30, green: 1.0,  blue: 0.57).opacity(0.30)
        }
    }

    var outerRingColor: Color {
        switch model.orbState {
        case .idle:      return .clear
        case .listening: return Color(red: 1.0,  green: 0.30, blue: 0.42).opacity(0.15)
        case .thinking:  return Color(red: 0.98, green: 0.78, blue: 0.20).opacity(0.18)
        case .speaking:  return Color(red: 0.30, green: 1.0,  blue: 0.57).opacity(0.12)
        }
    }
}

#if os(visionOS)
#Preview(windowStyle: .automatic) {
    VoiceOrbView()
        .environment(CrisisCopilotModel())
        .glassBackgroundEffect()
}
#endif
