//
//  ContentView.swift
//  Survivor MVP
//
//  Survivor — voice-native macOS layout.
//  Left: live camera. Right: floating panel with full clinical UI.
//

import SwiftUI

struct ContentView: View {
    @Environment(CrisisCopilotModel.self) private var model
    @State private var cameraModel = CameraFeedModel()
    @State private var voiceOrbModel = VoiceOrbModel()
    @State private var poseDetector = BodyPoseDetector()
    @State private var cameraPreviewEnabled = true
    @State private var showPoseOverlay = true

    var body: some View {
        ZStack(alignment: .trailing) {
            // Camera fills the full window
            cameraPane
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Floating frosted-glass sidebar
            VoicePanel(orbModel: voiceOrbModel)
                .frame(width: 320)
                .background(
                    .ultraThinMaterial.opacity(0.88),
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                )
                .shadow(color: .black.opacity(0.30), radius: 28, x: -6, y: 0)
                .padding(14)
        }
        .frame(minWidth: 760, minHeight: 520)
        .onAppear {
            cameraModel.start()
            cameraModel.setPoseDetector(poseDetector)
            voiceOrbModel.requestMicrophonePermissionIfNeeded()
            voiceOrbModel.copilotModel = model
            model.cameraModel = cameraModel
            model.poseDetector = poseDetector
            model.startEmergency()
        }
        .onDisappear { cameraModel.stop() }
    }

    /// Most recent assistant steps (drives the top-left overlay).
    private var latestSteps: [ChatStep] {
        model.messages.last(where: { $0.role == .assistant && !$0.steps.isEmpty })?.steps ?? []
    }

    @ViewBuilder
    private var cameraPane: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if cameraPreviewEnabled, cameraModel.status == .running, let session = cameraModel.session {
                ZStack {
                    CameraPreview(session: session)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // Body pose landmark overlay
                    if showPoseOverlay {
                        BodyPoseOverlayView(landmarks: poseDetector.detectedLandmarks)
                            .allowsHitTesting(false)
                    }
                }
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

            // Top-left controls + step navigator overlay
            VStack(alignment: .leading, spacing: 6) {
                // Camera + pose toggle controls
                HStack(spacing: 8) {
                    Toggle("", isOn: $cameraPreviewEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()

                    if cameraPreviewEnabled {
                        Toggle(isOn: $showPoseOverlay) {
                            Image(systemName: "figure.stand")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .toggleStyle(.button)
                        .controlSize(.small)
                        .help("Toggle body detection overlay")
                    }
                }
                .padding(10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))

                // Body detection status badge
                if cameraPreviewEnabled && showPoseOverlay {
                    PoseDetectionBadge(
                        landmarkCount: poseDetector.detectedLandmarks.count,
                        pulsePointCount: poseDetector.detectedLandmarks.filter { $0.category == .pulsePoint }.count,
                        isDetecting: poseDetector.isDetecting
                    )
                }

                // Step navigator — only visible when steps exist
                if !latestSteps.isEmpty {
                    StepNavigator(steps: latestSteps)
                        .frame(maxWidth: 300)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: .black.opacity(0.30), radius: 14, x: 0, y: 4)
                }

                Spacer()
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

/// visionOS: glass; macOS: material background.
struct PanelBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        #if os(visionOS)
        content
            .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        #else
        content
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        #endif
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
    @State private var emergencyPulse = false

    var body: some View {
        VStack(spacing: 0) {
            // Emergency 911 banner — only visible when call_emergency = true
            if model.callEmergency {
                EmergencyBanner(pulse: $emergencyPulse)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Header
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("Survivor")
                            .font(.headline)
                        UrgencyBadge(urgency: model.currentUrgency)
                    }
                    PhaseProgressDots(phase: model.currentPhase)
                }
                Spacer()
                SessionTimerView(startTime: model.sessionStartTime)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // Diagnosis card — appears after assessment phase
            if let diagnosis = model.currentDiagnosis {
                DiagnosisCard(
                    diagnosis: diagnosis,
                    confidence: model.diagnosisConfidence,
                    findings: model.keyFindings
                )
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
            }

            // Vitals strip — appears when any vitals captured
            if !model.extractedVitals.isEmpty {
                VitalsStrip(vitals: model.extractedVitals)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 6)
            }

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
                        if model.isProcessing {
                            ThinkingBubble()
                                .id("thinking")
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
                .onChange(of: model.isProcessing) { _, processing in
                    if processing {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo("thinking", anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Full animated orb
            VStack(spacing: 14) {
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
            .padding(.vertical, 20)
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
            .onChange(of: model.callEmergency) { _, emergency in
                if emergency {
                    withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                        emergencyPulse = true
                    }
                }
            }
        }
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
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
            break
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

// MARK: - Emergency Banner

private struct EmergencyBanner: View {
    @Binding var pulse: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "phone.fill")
                .font(.system(size: 14, weight: .bold))
            Text("CALL 911 NOW")
                .font(.system(size: 13, weight: .black))
                .tracking(1.5)
            Spacer()
            // Tappable on macOS — opens dialer on iOS/visionOS
            Link("📞 Call", destination: URL(string: "tel:6696679710")!)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.white.opacity(0.25), in: Capsule())
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            pulse
                ? Color.red
                : Color(red: 0.8, green: 0, blue: 0),
            in: Rectangle()
        )
        .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: pulse)
        .onAppear {
            pulse = true
        }
    }
}

// MARK: - Urgency Badge

private struct UrgencyBadge: View {
    let urgency: String

    private var label: String {
        urgency.uppercased()
    }

    private var color: Color {
        switch urgency {
        case "low":      return Color(red: 0.18, green: 0.65, blue: 0.33)
        case "medium":   return Color(red: 0.90, green: 0.62, blue: 0.0)
        case "high":     return Color(red: 0.92, green: 0.38, blue: 0.0)
        case "critical": return Color(red: 0.85, green: 0.06, blue: 0.06)
        default:         return .secondary
        }
    }

    var body: some View {
        Text(label)
            .font(.system(size: 9, weight: .bold))
            .tracking(0.8)
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color, in: Capsule())
    }
}

// MARK: - Phase Progress Dots

private struct PhaseProgressDots: View {
    let phase: String

    private var phaseIndex: Int {
        switch phase {
        case "questioning": return 0
        case "assessment":  return 1
        case "treatment":   return 2
        default:            return 0
        }
    }

    private let labels = ["Assess", "Diagnose", "Treat"]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3) { i in
                HStack(spacing: 4) {
                    Circle()
                        .fill(i <= phaseIndex ? Color.accentColor : Color.primary.opacity(0.15))
                        .frame(width: 6, height: 6)
                    if i <= phaseIndex {
                        Text(labels[i])
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(i == phaseIndex ? Color.accentColor : Color.primary.opacity(0.4))
                    }
                }
                if i < 2 {
                    Rectangle()
                        .fill(i < phaseIndex ? Color.accentColor.opacity(0.4) : Color.primary.opacity(0.1))
                        .frame(width: 12, height: 1)
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: phase)
    }
}

// MARK: - Session Timer

private struct SessionTimerView: View {
    let startTime: Date?
    @State private var elapsed: TimeInterval = 0
    @State private var timer: Timer? = nil

    var body: some View {
        Group {
            if startTime != nil {
                Text(formattedTime)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .onAppear { startTimer() }
        .onDisappear { timer?.invalidate() }
        .onChange(of: startTime) { _, _ in startTimer() }
    }

    private var formattedTime: String {
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func startTimer() {
        timer?.invalidate()
        guard let start = startTime else { return }
        elapsed = Date().timeIntervalSince(start)
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsed = Date().timeIntervalSince(start)
        }
    }
}

// MARK: - Diagnosis Card

private struct DiagnosisCard: View {
    let diagnosis: String
    let confidence: Int
    let findings: [String]

    private var confidenceColor: Color {
        if confidence >= 80 { return Color(red: 0.18, green: 0.65, blue: 0.33) }
        if confidence >= 60 { return Color(red: 0.90, green: 0.62, blue: 0.0) }
        return Color(red: 0.92, green: 0.38, blue: 0.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "stethoscope")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(diagnosis)
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                if confidence > 0 {
                    Text("\(confidence)%")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(confidenceColor)
                }
            }
            if !findings.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(findings, id: \.self) { finding in
                        HStack(spacing: 5) {
                            Circle()
                                .fill(Color.secondary.opacity(0.5))
                                .frame(width: 4, height: 4)
                            Text(finding)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(10)
        .background(Color.accentColor.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.accentColor.opacity(0.15), lineWidth: 1)
        )
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.spring(duration: 0.4), value: diagnosis)
    }
}

// MARK: - Vitals Strip

private struct VitalsStrip: View {
    let vitals: [String: Double]

    private var orderedVitals: [(key: String, value: Double, label: String, unit: String, icon: String)] {
        let map: [(String, String, String, String)] = [
            ("hr",   "HR",   "bpm",  "heart.fill"),
            ("rr",   "RR",   "/min", "lungs.fill"),
            ("spo2", "SpO₂", "%",    "waveform.path.ecg"),
            ("sbp",  "BP",   "mmHg", "gauge"),
            ("gcs",  "GCS",  "/15",  "brain.head.profile"),
            ("temp", "Temp", "°C",   "thermometer.medium"),
        ]
        return map.compactMap { key, label, unit, icon in
            guard let val = vitals[key] else { return nil }
            return (key: key, value: val, label: label, unit: unit, icon: icon)
        }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(orderedVitals, id: \.key) { vital in
                    VitalCard(
                        icon: vital.icon,
                        label: vital.label,
                        value: formattedValue(vital.value, key: vital.key),
                        unit: vital.unit,
                        isAbnormal: isAbnormal(value: vital.value, key: vital.key)
                    )
                }
            }
            .padding(.vertical, 2)
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.3), value: vitals.count)
    }

    private func formattedValue(_ val: Double, key: String) -> String {
        if key == "gcs" || key == "hr" || key == "rr" || key == "sbp" {
            return String(Int(val))
        }
        return String(format: "%.1f", val)
    }

    private func isAbnormal(value: Double, key: String) -> Bool {
        switch key {
        case "hr":   return value < 50 || value > 120
        case "rr":   return value < 8 || value > 25
        case "spo2": return value < 94
        case "gcs":  return value < 13
        case "sbp":  return value < 90 || value > 180
        case "temp": return value < 35 || value > 38.5
        default:     return false
        }
    }
}

private struct VitalCard: View {
    let icon: String
    let label: String
    let value: String
    let unit: String
    let isAbnormal: Bool

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isAbnormal ? .red : .secondary)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(isAbnormal ? .red : .primary)
            Text("\(label) \(unit)")
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 52)
        .padding(.vertical, 7)
        .padding(.horizontal, 8)
        .background(
            isAbnormal ? Color.red.opacity(0.08) : Color.primary.opacity(0.04),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isAbnormal ? Color.red.opacity(0.3) : .clear, lineWidth: 1)
        )
    }
}

// MARK: - Thinking bubble

private struct ThinkingBubble: View {
    @State private var phase = 0.0

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            HStack(spacing: 5) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Color.secondary.opacity(0.5))
                        .frame(width: 6, height: 6)
                        .offset(y: sin(phase + Double(i) * 1.2) * 3)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            Spacer(minLength: 32)
        }
        .onAppear {
            withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
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

                // Treatment steps — navigable one-at-a-time card
                if !message.steps.isEmpty {
                    StepNavigator(steps: message.steps)
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

private struct StepNavigator: View {
    let steps: [ChatStep]
    @State private var currentIndex: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: step counter + nav arrows
            HStack {
                Text("Step \(currentIndex + 1) of \(steps.count)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 4) {
                    Button {
                        if currentIndex > 0 { currentIndex -= 1 }
                    } label: {
                        Image(systemName: "chevron.left")
                            .imageScale(.small)
                    }
                    .disabled(currentIndex == 0)
                    .buttonStyle(.plain)

                    Button {
                        if currentIndex < steps.count - 1 { currentIndex += 1 }
                    } label: {
                        Image(systemName: "chevron.right")
                            .imageScale(.small)
                    }
                    .disabled(currentIndex == steps.count - 1)
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            StepCard(number: currentIndex + 1, step: steps[currentIndex])
        }
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onChange(of: steps.count) { _, _ in
            currentIndex = 0
        }
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
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.primary.opacity(0.05))
                            .frame(width: 240, height: 100)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundStyle(.secondary)
                            )
                    case .empty:
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.primary.opacity(0.05))
                            .frame(width: 240, height: 100)
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

// MARK: - Panel background (visionOS: glass; macOS: material)
struct PanelBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        #if os(visionOS)
        content
            .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        #else
        content
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        #endif
    }
}

#Preview("Survivor") {
    ContentView()
        .environment(AppModel())
        .environment(CrisisCopilotModel())
        .frame(width: 960, height: 620)
}
