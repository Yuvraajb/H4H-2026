//
//  ContentView.swift
//  Survivor MVP
//
//  Crisis Copilot — full-window camera background with one left overlay panel.
//

import SwiftUI

struct ContentView: View {
    @Environment(CrisisCopilotModel.self) private var model
    @State private var cameraModel = CameraFeedModel()
    @State private var cameraPreviewEnabled = true

    var body: some View {
        ZStack {
            cameraBackgroundLayer
                .ignoresSafeArea()
                .allowsHitTesting(false)

            HStack(alignment: .top, spacing: 0) {
                CrisisCopilotPanelView(
                    cameraModel: cameraModel,
                    cameraPreviewEnabled: $cameraPreviewEnabled
                )
                .frame(width: 400)
                .modifier(PanelBackgroundModifier())
                Spacer(minLength: 0)
            }
            .padding(24)
        }
        .frame(minWidth: 500, minHeight: 500)
        .onAppear {
            if cameraPreviewEnabled { cameraModel.start() }
        }
        .onDisappear {
            cameraModel.stop()
        }
        .onChange(of: cameraPreviewEnabled) { _, enabled in
            if enabled {
                cameraModel.start()
            } else {
                cameraModel.stop()
            }
        }
    }

    @ViewBuilder
    private var cameraBackgroundLayer: some View {
        if cameraPreviewEnabled {
            if cameraModel.status == .running, let session = cameraModel.session {
                CameraPreview(session: session)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ZStack {
                    Color.black
                    VStack(spacing: 8) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text(cameraStatusText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } else { 
            Color.black
        }
    }

    private var cameraStatusText: String {
        switch cameraModel.status {
        case .idle: return "Starting camera…"
        case .requestingPermission: return "Requesting camera permission…"
        case .unauthorized: return "Camera permission denied."
        case .unavailable: return "No camera available."
        case .running: return ""
        case .failed(let message): return message
        }
    }
}

/// Semi-transparent / glass style for panels.
struct PanelBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        #if os(visionOS)
        content
            .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        #else
        content
            .background(.ultraThinMaterial.opacity(0.88), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        #endif
    }
}

#if os(visionOS)
#Preview(windowStyle: .automatic) {
    ContentView()
        .environment(AppModel())
        .environment(CrisisCopilotModel())
}
#else
#Preview("Crisis Copilot") {
    ContentView()
        .environment(AppModel())
        .environment(CrisisCopilotModel())
        .frame(width: 1000, height: 600)
}
#endif
