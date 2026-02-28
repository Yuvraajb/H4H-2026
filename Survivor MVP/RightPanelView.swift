//
//  RightPanelView.swift
//  Survivor MVP
//
//  Crisis Copilot — camera preview card + suggested actions.
//

import SwiftUI

struct RightPanelView: View {
    @Environment(CrisisCopilotModel.self) private var model
    var cameraModel: CameraFeedModel
    @Binding var cameraPreviewEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            cameraCard
            suggestedActionsCard
            Spacer(minLength: 0)
        }
        .padding(24)
        .modifier(PanelBackgroundModifier())
    }

    private var cameraCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Live Camera")
                    .font(.headline)
                if cameraPreviewEnabled, cameraModel.status == .running {
                    Text("Live")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.3), in: Capsule())
                }
                Spacer()
                Toggle("", isOn: $cameraPreviewEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            if cameraPreviewEnabled {
                if cameraModel.status == .running, let session = cameraModel.session {
                    CameraPreview(session: session)
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    cameraPlaceholder
                }
            } else {
                Text("Camera off")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private var cameraPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text(cameraStatusText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 180)
        .background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var cameraStatusText: String {
        switch cameraModel.status {
        case .idle: return "Starting…"
        case .requestingPermission: return "Requesting permission…"
        case .unauthorized: return "Camera permission denied."
        case .unavailable: return "No camera available."
        case .running: return ""
        case .failed(let msg): return msg
        }
    }

    private var suggestedActionsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Suggested actions")
                .font(.headline)
            if model.suggestedActions.isEmpty {
                Text("Start an emergency to see suggested actions.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(model.suggestedActions, id: \.self) { action in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("•")
                                .foregroundStyle(.secondary)
                            Text(action)
                                .font(.subheadline)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    RightPanelView(
        cameraModel: CameraFeedModel(),
        cameraPreviewEnabled: .constant(true)
    )
    .environment(CrisisCopilotModel())
    .frame(width: 360, height: 500)
}
