//
//  ActionOverlayView.swift
//  Survivor MVP
//
//  Visual feedback overlay for action verification:
//  guide rings, placement confirmations, countdown timers,
//  and beat count entry for pulse measurement.
//

import SwiftUI

struct ActionOverlayView: View {
    let verifier: ActionVerifier
    let bodyLandmarks: [DetectedLandmark]
    let viewSize: CGSize
    var onBeatCount: ((Int) -> Void)?

    var body: some View {
        ZStack {
            switch verifier.state {
            case .idle:
                EmptyView()

            case .guiding:
                guidingOverlay

            case .confirmed:
                confirmedOverlay

            case .acting:
                actingOverlay

            case .complete:
                completeOverlay
            }
        }
        .animation(.easeInOut(duration: 0.3), value: verifier.state)
    }

    // MARK: - Guiding: show target ring + instruction

    @ViewBuilder
    private var guidingOverlay: some View {
        // Target ring at the landmark position
        if let targetPos = targetScreenPosition {
            TargetRingView()
                .position(targetPos)
        }

        // Instruction banner at bottom
        InstructionBanner(text: verifier.guidanceText, color: .orange)
    }

    // MARK: - Confirmed: green checkmark flash

    @ViewBuilder
    private var confirmedOverlay: some View {
        if let targetPos = targetScreenPosition {
            ConfirmationCheckmark()
                .position(targetPos)
        }

        InstructionBanner(text: verifier.guidanceText, color: .green)
    }

    // MARK: - Acting: depends on action type

    @ViewBuilder
    private var actingOverlay: some View {
        switch verifier.currentAction {
        case .pulseCheck:
            pulseTimerOverlay

        case .cpr:
            cprConfirmationOverlay

        case .headTiltChinLift:
            airwayConfirmationOverlay

        case .none:
            EmptyView()
        }
    }

    @ViewBuilder
    private var pulseTimerOverlay: some View {
        VStack(spacing: 12) {
            Text("\(verifier.timerRemaining)")
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .shadow(color: .black.opacity(0.6), radius: 8)

            Text("COUNT THE BEATS")
                .font(.system(size: 14, weight: .black))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.9))
                .shadow(color: .black.opacity(0.5), radius: 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)

        // Pulsing border
        RoundedRectangle(cornerRadius: 0)
            .stroke(Color.red.opacity(0.4), lineWidth: 4)
            .ignoresSafeArea()
            .animation(
                .easeInOut(duration: 0.5).repeatForever(autoreverses: true),
                value: verifier.timerRemaining
            )
    }

    @ViewBuilder
    private var cprConfirmationOverlay: some View {
        if let targetPos = targetScreenPosition {
            ConfirmationCheckmark()
                .position(targetPos)
        }

        InstructionBanner(text: verifier.guidanceText, color: .green)
    }

    @ViewBuilder
    private var airwayConfirmationOverlay: some View {
        if let targetPos = targetScreenPosition {
            ConfirmationCheckmark()
                .position(targetPos)
        }

        InstructionBanner(text: verifier.guidanceText, color: .green)
    }

    // MARK: - Complete: beat count entry (pulse only)

    @ViewBuilder
    private var completeOverlay: some View {
        if case .pulseCheck = verifier.currentAction {
            BeatCountEntryView(onSubmit: { count in
                onBeatCount?(count)
            })
        } else {
            InstructionBanner(text: "Action verified", color: .green)
        }
    }

    // MARK: - Helpers

    private var targetScreenPosition: CGPoint? {
        guard let targetName = verifier.targetLandmarkName,
              let landmark = bodyLandmarks.first(where: { $0.name == targetName }) else {
            return nil
        }
        // Convert Vision coords (bottom-left) → SwiftUI (top-left), mirrored for front camera
        return CGPoint(
            x: (1 - landmark.point.x) * viewSize.width,
            y: (1 - landmark.point.y) * viewSize.height
        )
    }
}

// MARK: - Target Ring (animated pulsing ring)

private struct TargetRingView: View {
    @State private var pulse = false

    var body: some View {
        ZStack {
            // Outer pulsing ring
            Circle()
                .stroke(Color.orange.opacity(0.4), lineWidth: 3)
                .frame(width: 70, height: 70)
                .scaleEffect(pulse ? 1.4 : 1.0)
                .opacity(pulse ? 0.0 : 0.8)

            // Inner dashed ring
            Circle()
                .stroke(Color.orange, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                .frame(width: 50, height: 50)

            // Center crosshair
            Image(systemName: "hand.point.up.fill")
                .font(.system(size: 18))
                .foregroundStyle(.orange)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
    }
}

// MARK: - Confirmation Checkmark

private struct ConfirmationCheckmark: View {
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0.0

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.green.opacity(0.3))
                .frame(width: 60, height: 60)

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.green)
                .shadow(color: .green.opacity(0.5), radius: 8)
        }
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
}

// MARK: - Instruction Banner

private struct InstructionBanner: View {
    let text: String
    let color: Color

    var body: some View {
        VStack {
            Spacer()
            Text(text)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(color.opacity(0.85), in: Capsule())
                .shadow(color: .black.opacity(0.3), radius: 8)
                .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Beat Count Entry

private struct BeatCountEntryView: View {
    let onSubmit: (Int) -> Void
    @State private var selectedCount: Int? = nil

    private let commonCounts = Array(8...30)

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            VStack(spacing: 12) {
                Text("How many beats did you count?")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)

                // Quick-pick grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                    ForEach(commonCounts, id: \.self) { count in
                        Button {
                            selectedCount = count
                        } label: {
                            Text("\(count)")
                                .font(.system(size: 16, weight: selectedCount == count ? .bold : .medium, design: .rounded))
                                .frame(width: 44, height: 40)
                                .background(
                                    selectedCount == count
                                        ? Color.green.opacity(0.8)
                                        : Color.white.opacity(0.2),
                                    in: RoundedRectangle(cornerRadius: 8)
                                )
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)

                if let count = selectedCount {
                    let bpm = count * 4
                    Text("= \(bpm) BPM")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.green)

                    Button {
                        onSubmit(count)
                    } label: {
                        Text("Confirm")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 10)
                            .background(Color.green, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.4), radius: 16)
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
    }
}
