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
        }
        .windowResizability(.contentMinSize)
    }
}
