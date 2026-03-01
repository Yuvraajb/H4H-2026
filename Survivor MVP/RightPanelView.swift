//
//  RightPanelView.swift
//  Survivor MVP
//
//  Crisis Copilot — camera preview card + suggested actions.
//

import SwiftUI
#if os(macOS)
import AppKit
#endif
#if os(iOS) || os(visionOS)
import UIKit
#endif

struct RightPanelView: View {
    @Environment(CrisisCopilotModel.self) private var model
    var cameraModel: CameraFeedModel
    @Binding var cameraPreviewEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            cameraCard
            stepsCard
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

    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Steps")
                .font(.headline)
            if model.instructionSteps.isEmpty {
                Text("Describe what's happening — steps with images will appear here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(model.instructionSteps) { step in
                            StepRowView(
                                stepNumber: step.stepNumber,
                                title: step.title,
                                imageData: model.stepImageData[step.id]
                            )
                        }
                    }
                }
                .frame(maxHeight: 280)
            }
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

// MARK: - Step row (WikiHow-style: number + title + image)
private struct StepRowView: View {
    let stepNumber: Int
    let title: String
    let imageData: Data?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Step \(stepNumber)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.subheadline)
            }
            if let data = imageData {
                stepImage(from: data)
            } else if imageData == nil {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.black.opacity(0.15))
                    .frame(height: 80)
                    .overlay {
                        ProgressView()
                    }
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private func stepImage(from data: Data) -> some View {
        #if os(macOS)
        stepImageMac(data: data)
        #else
        stepImageIOS(data: data)
        #endif
    }
}

#if os(macOS)
private func stepImageMac(data: Data) -> some View {
    Group {
        if let nsImage = NSImage(data: data) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 140)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}
#else
import UIKit
private func stepImageIOS(data: Data) -> some View {
    Group {
        if let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 140)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}
#endif

#Preview {
    RightPanelView(
        cameraModel: CameraFeedModel(),
        cameraPreviewEnabled: .constant(true)
    )
    .environment(CrisisCopilotModel())
    .frame(width: 360, height: 500)
}
