//
//  MainCopilotView.swift
//  Survivor MVP
//
//  Legacy center panel; chat UI lives in CopilotChatView.
//

import SwiftUI

struct MainCopilotView: View {
    @Environment(CrisisCopilotModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Crisis Copilot")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Use the center chat panel for conversation.")
                .font(.body)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .modifier(PanelBackgroundModifier())
    }
}

#Preview {
    MainCopilotView()
        .environment(CrisisCopilotModel())
        .frame(width: 400, height: 400)
}
