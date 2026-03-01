//
//  Survivor_MVPApp.swift
//  Survivor MVP
//
//  Created by Krishna Chandra Gummadi on 2/24/26.
//

import SwiftUI

@main
struct Survivor_MVPApp: App {

    @State private var appModel = AppModel()
    @State private var avPlayerViewModel = AVPlayerViewModel()
    @State private var crisisCopilotModel = CrisisCopilotModel()

    var body: some Scene {
        #if os(visionOS)
        // Bootstrap: opens four dashboard windows + mic, then dismisses itself so user sees only floating panels and real world.
        WindowGroup(id: "bootstrap") {
            BootstrapView()
                .environment(appModel)
                .environment(crisisCopilotModel)
        }
        .defaultSize(CGSize(width: 100, height: 100))

        WindowGroup(id: "dispatch") {
            DispatchWindowView()
                .environment(appModel)
                .environment(crisisCopilotModel)
        }
        .defaultSize(CGSize(width: 360, height: 500))

        WindowGroup(id: "live-guidance") {
            LiveGuidanceWindowView()
                .environment(appModel)
                .environment(crisisCopilotModel)
        }
        .defaultSize(CGSize(width: 380, height: 420))

        WindowGroup(id: "protocols") {
            ProtocolsWindowView()
                .environment(appModel)
                .environment(crisisCopilotModel)
        }
        .defaultSize(CGSize(width: 300, height: 280))

        WindowGroup(id: "location") {
            LocationETAWindowView()
                .environment(appModel)
                .environment(crisisCopilotModel)
        }
        .defaultSize(CGSize(width: 360, height: 340))

        WindowGroup(id: "mic") {
            FloatingMicView()
                .environment(appModel)
                .environment(crisisCopilotModel)
        }
        .defaultSize(CGSize(width: 220, height: 90))

        // Optional immersive space — not opened by default so user always sees real world.
        ImmersiveSpace(id: appModel.immersiveSpaceID) {
            ImmersiveView()
                .environment(appModel)
                .onAppear {
                    appModel.immersiveSpaceState = .open
                    avPlayerViewModel.play()
                }
                .onDisappear {
                    appModel.immersiveSpaceState = .closed
                    avPlayerViewModel.reset()
                }
        }
        .immersionStyle(selection: .constant(.progressive), in: .progressive)
        #else
        WindowGroup {
            if avPlayerViewModel.isPlaying {
                AVPlayerView(viewModel: avPlayerViewModel)
            } else {
                ContentView()
                    .environment(appModel)
                    .environment(crisisCopilotModel)
            }
        }
        #endif
    }
}
