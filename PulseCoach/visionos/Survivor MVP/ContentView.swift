//
//  ContentView.swift
//  Survivor MVP
//
//  PulseCoach — 3-column layout: left rail, main copilot, visual instructions.
//

import SwiftUI

struct ContentView: View {
    @Environment(PulseCoachModel.self) private var model

    var body: some View {
        ZStack {
            HStack(spacing: 16) {
                LeftRailView()
                    .frame(width: 280)

                MainCopilotView()
                    .frame(minWidth: 520, maxWidth: .infinity)

                VisualInstructionView()
                    .frame(width: 360)
            }
            .padding(24)
        }
        .frame(minWidth: 900, minHeight: 500)
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

#if os(visionOS)
#Preview(windowStyle: .automatic) {
    ContentView()
        .environment(AppModel())
        .environment(PulseCoachModel())
}
#else
#Preview("PulseCoach") {
    ContentView()
        .environment(AppModel())
        .environment(PulseCoachModel())
        .frame(width: 1000, height: 600)
}
#endif
