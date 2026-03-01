//
//  FloatingMicView.swift
//  Survivor MVP
//
//  Central floating mic + home/settings for First Responder dashboard.
//

import SwiftUI

struct FloatingMicView: View {
    @Environment(CrisisCopilotModel.self) private var model

    var body: some View {
        HStack(spacing: 12) {
            Button(action: {}) {
                Image(systemName: "house.fill")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            Rectangle()
                .fill(.white.opacity(0.2))
                .frame(width: 1, height: 28)
            Button(action: { model.simulateVoiceInput() }) {
                Image(systemName: "mic.fill")
                    .font(.title)
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.emergencyPrimary, in: Circle())
            }
            .buttonStyle(.plain)
            Rectangle()
                .fill(.white.opacity(0.2))
                .frame(width: 1, height: 28)
            Button(action: {}) {
                Image(systemName: "gearshape.fill")
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(.ultraThinMaterial, in: Capsule())
        .modifier(PanelBackgroundModifier())
        .frame(minWidth: 200, minHeight: 80)
    }
}

#Preview {
    FloatingMicView()
        .environment(CrisisCopilotModel())
}
