//
//  LiveGuidanceWindowView.swift
//  Survivor MVP
//
//  First Responder dashboard — Live Guidance panel: CPR / procedure guidance.
//

import SwiftUI

struct LiveGuidanceWindowView: View {
    @Environment(CrisisCopilotModel.self) private var model
    @State private var heartScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            // Dark translucent background (reference: darker panel)
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                liveGuidanceBadge
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                ZStack {
                    // CPR hands placeholder (simplified: two overlapping circles for hand position)
                    cprPlaceholder
                    instructionOverlay
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .modifier(PanelBackgroundModifier())
        .frame(minWidth: 340, minHeight: 360)
    }

    private var liveGuidanceBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.emergencyPrimary)
                .frame(width: 8, height: 8)
                .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 1))
            Text("LIVE GUIDANCE")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.black.opacity(0.4), in: Capsule())
    }

    private var cprPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.black.opacity(0.3))
                .overlay(
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.white.opacity(0.4))
                        .symbolEffect(.pulse, options: .repeating)
                )
        }
        .padding(12)
    }

    private var instructionOverlay: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color.emergencyPrimary.opacity(0.6), lineWidth: 3)
                    .frame(width: 64, height: 64)
                    .scaleEffect(heartScale)
                Image(systemName: "heart.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    heartScale = 1.15
                }
            }
            VStack(spacing: 6) {
                Text("Push Hard & Fast")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                Text("Place heel of hand on center of chest. Push down at least 2 inches at 100-120 beats per minute.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
            }
            heartbeatBars
        }
        .padding(16)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(20)
    }

    private var heartbeatBars: some View {
        HStack(spacing: 4) {
            ForEach([0.3, 0.5, 0.8, 0.5, 0.3], id: \.self) { h in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.emergencyPrimary)
                    .frame(width: 6, height: 12 * h)
            }
        }
        .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: heartScale)
    }
}

#Preview {
    LiveGuidanceWindowView()
        .environment(CrisisCopilotModel())
        .frame(width: 380, height: 420)
}
