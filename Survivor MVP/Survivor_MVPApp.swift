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
        WindowGroup {
            if avPlayerViewModel.isPlaying {
                AVPlayerView(viewModel: avPlayerViewModel)
            } else {
                ContentView()
                    .environment(appModel)
                    .environment(crisisCopilotModel)
            }
        }

        #if os(visionOS)
        WindowGroup("Voice Orb", id: "voice-orb") {
            VoiceOrbView()
                .environment(crisisCopilotModel)
                .glassBackgroundEffect()
        }
        .defaultSize(width: 280, height: 380)
        .windowResizability(.contentSize)

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
        #endif
    }
}
