//
//  Survivor_MVPApp.swift
//  Survivor MVP
//

import SwiftUI

@main
struct Survivor_MVPApp: App {

    @State private var appModel = AppModel()
    @State private var crisisCopilotModel = CrisisCopilotModel()

    init() {
        // Simulator shares the Mac's network stack, so 127.0.0.1 works there.
        // Physical devices need the Mac's actual LAN IP.
        #if !targetEnvironment(simulator)
        BackendService.deviceBaseURLOverride = "http://172.31.190.194:8000"
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appModel)
                .environment(crisisCopilotModel)
                .onAppear { BackendLauncher.shared.startIfNeeded() }
                .onDisappear { BackendLauncher.shared.stop() }
        }
        .windowResizability(.contentMinSize)
    }
}
