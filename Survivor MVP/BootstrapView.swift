//
//  BootstrapView.swift
//  Survivor MVP
//
//  visionOS: opens the four dashboard windows then dismisses this window.
//

import SwiftUI

struct BootstrapView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .onAppear {
                openWindow(id: "dispatch")
                openWindow(id: "live-guidance")
                openWindow(id: "protocols")
                openWindow(id: "location")
                openWindow(id: "mic")
                dismissWindow(id: "bootstrap")
            }
    }
}
