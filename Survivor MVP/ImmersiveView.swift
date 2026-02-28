//
//  ImmersiveView.swift
//  Survivor MVP
//
//  Created by Krishna Chandra Gummadi on 2/24/26.
//  visionOS only; macOS gets EmptyView.
//

import SwiftUI
#if os(visionOS)
import RealityKit
import RealityKitContent
#endif

struct ImmersiveView: View {
    @Environment(AppModel.self) var appModel

    var body: some View {
        #if os(visionOS)
        RealityView { content in
            if let immersiveContentEntity = try? await Entity(named: "Immersive", in: realityKitContentBundle) {
                content.add(immersiveContentEntity)
            }
        }
        #else
        EmptyView()
        #endif
    }
}

#if os(visionOS)
#Preview(immersionStyle: .progressive) {
    ImmersiveView()
        .environment(AppModel())
}
#endif
