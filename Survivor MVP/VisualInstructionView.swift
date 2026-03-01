//
//  VisualInstructionView.swift
//  Survivor MVP
//
//  Legacy right panel; camera + suggested actions live in RightPanelView.
//

import SwiftUI

struct VisualInstructionView: View {
    @Environment(CrisisCopilotModel.self) private var model
    var cameraModel: CameraFeedModel
    @Binding var cameraPreviewEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Visual guide")
                .font(.headline)
            Text("Camera and suggested actions are in the right panel.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .modifier(PanelBackgroundModifier())
    }
}

#Preview {
    VisualInstructionView(
        cameraModel: CameraFeedModel(),
        cameraPreviewEnabled: .constant(true)
    )
    .environment(CrisisCopilotModel())
    .frame(width: 360, height: 400)
}
