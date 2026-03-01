//
//  Survivor_MVPApp.swift
//  Survivor MVP
//

import SwiftUI

@main
struct Survivor_MVPApp: App {

    @State private var appModel = AppModel()
    @State private var crisisCopilotModel = CrisisCopilotModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appModel)
                .environment(crisisCopilotModel)
                .onAppear { BackendLauncher.shared.startIfNeeded() }
                .onDisappear { BackendLauncher.shared.stop() }
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1200, height: 800)
    }
}
