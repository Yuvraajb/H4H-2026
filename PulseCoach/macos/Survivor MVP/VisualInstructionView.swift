//
//  VisualInstructionView.swift
//  Survivor MVP
//
//  Right panel: diagram placeholders by current step (SF Symbols + shapes, no external images).
//

import SwiftUI

struct VisualInstructionView: View {
    @Environment(PulseCoachModel.self) private var model
    @State private var cameraModel = CameraFeedModel()
    @State private var cameraPreviewEnabled = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Visual guide")
                    .font(.headline)

                cameraSection

                instructionContent
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .modifier(PanelBackgroundModifier())
        .onAppear {
            if cameraPreviewEnabled { cameraModel.start() }
        }
        .onDisappear {
            cameraModel.stop()
        }
        .onChange(of: cameraPreviewEnabled) { _, enabled in
            if enabled {
                cameraModel.start()
            } else {
                cameraModel.stop()
            }
        }
    }

    @ViewBuilder
    private var cameraSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Camera preview", isOn: $cameraPreviewEnabled)
                .toggleStyle(.switch)

            if cameraPreviewEnabled {
                cameraPreviewCard
            }
        }
    }

    @ViewBuilder
    private var cameraPreviewCard: some View {
        Group {
            if cameraModel.status == .running, let session = cameraModel.session {
                CameraPreview(session: session)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                cameraPlaceholder
            }
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var cameraPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: cameraPlaceholderIcon)
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text(cameraPlaceholderText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
    }

    private var cameraPlaceholderIcon: String {
        switch cameraModel.status {
        case .idle, .requestingPermission: return "camera.viewfinder"
        case .unauthorized: return "camera.badge.exclamationmark"
        case .unavailable: return "camera.fill"
        case .running: return "camera.fill"
        case .failed: return "exclamationmark.triangle"
        }
    }

    private var cameraPlaceholderText: String {
        switch cameraModel.status {
        case .idle: return "Starting camera…"
        case .requestingPermission: return "Requesting camera permission…"
        case .unauthorized: return "Camera permission denied. Enable camera in Settings."
        case .unavailable: return "No camera available (simulator may not provide one)."
        case .running: return ""
        case .failed(let message): return message
        }
    }

    @ViewBuilder
    private var instructionContent: some View {
        switch model.currentImageHint {
        case .none:
            placeholderView(
                icon: "checklist",
                title: "Follow the steps",
                detail: "Current step has no diagram. Use the center panel for instructions."
            )
        case .pulseRadial:
            pulseRadialDiagram
        case .pulseCarotid:
            pulseCarotidDiagram
        case .recoveryPosition:
            recoveryPositionDiagram
        case .cprHands:
            cprHandsDiagram
        case .call911:
            call911Diagram
        }
    }

    private func placeholderView(icon: String, title: String, detail: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
    }

    private var pulseRadialDiagram: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Radial pulse (wrist)")
                .font(.headline)
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.quaternary)
                    .frame(width: 140, height: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(.secondary.opacity(0.5), lineWidth: 1)
                    )
                Circle()
                    .fill(Color.accentColor.opacity(0.6))
                    .frame(width: 24, height: 24)
                    .overlay(Text("2").font(.caption2).fontWeight(.bold))
                    .offset(x: 32, y: -24)
            }
            Text("2 fingers here")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Inside of wrist, below base of thumb. Count for 15 seconds.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var pulseCarotidDiagram: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Carotid pulse (neck)")
                .font(.headline)
            HStack(spacing: 20) {
                Image(systemName: "figure.stand")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.quaternary)
                        .frame(width: 60, height: 24)
                    Circle()
                        .fill(Color.accentColor.opacity(0.6))
                        .frame(width: 20, height: 20)
                        .overlay(Text("2").font(.caption2).fontWeight(.bold))
                        .offset(x: 8, y: -2)
                }
            }
            Text("2 fingers on side of neck, next to windpipe.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var recoveryPositionDiagram: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recovery position")
                .font(.headline)
            Image(systemName: "figure.roll")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Label("Roll onto side", systemImage: "arrow.turn.down.right")
                Label("Head supported, airway open", systemImage: "checkmark.circle")
            }
            .font(.subheadline)
        }
    }

    private var cprHandsDiagram: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("CPR hand placement")
                .font(.headline)
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 48))
                .foregroundStyle(.red.opacity(0.8))
            Text("Hands center chest")
                .font(.subheadline)
                .fontWeight(.medium)
            Text("Heel of one hand on center of chest, other on top. Push hard and fast, 100–120/min.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var call911Diagram: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Call 911")
                .font(.headline)
            Image(systemName: "phone.fill")
                .font(.system(size: 48))
                .foregroundStyle(.red)
            VStack(alignment: .leading, spacing: 6) {
                Text("Say:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("• Location")
                Text("• Breathing status")
                Text("• Pulse status")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    VisualInstructionView()
        .environment(PulseCoachModel())
        .frame(width: 360, height: 400)
}
