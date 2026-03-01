//
//  CameraPreview.swift
//  Survivor MVP
//
//  Cross-platform live camera feed: CameraPreview(session: AVCaptureSession).
//  - visionOS: AVCaptureVideoPreviewLayer is unavailable → placeholder only.
//  - macOS: NSViewRepresentable + NSView + AVCaptureVideoPreviewLayer (live webcam).
//  - iOS: UIViewRepresentable + UIView + AVCaptureVideoPreviewLayer.
//  Simulator for visionOS may show unavailable; macOS target will show live webcam.
//

import AVFoundation
import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

struct CameraPreview: View {
    let session: AVCaptureSession

    var body: some View {
#if os(visionOS)
        visionOSPlaceholder
#elseif os(macOS)
        CameraPreviewNSViewRepresentable(session: session)
            .ignoresSafeArea()
#else
        CameraPreviewUIViewRepresentable(session: session)
            .ignoresSafeArea()
#endif
    }

#if os(visionOS)
    private var visionOSPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "video.fill")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Live camera preview")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Preview not available in simulator")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
#endif
}

// MARK: - macOS (NSView + AVCaptureVideoPreviewLayer)
#if os(macOS)
private final class CameraPreviewNSView: NSView {
    var previewLayer: AVCaptureVideoPreviewLayer!

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        previewLayer = AVCaptureVideoPreviewLayer()
        previewLayer.videoGravity = .resizeAspectFill
        layer = previewLayer
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setSession(_ session: AVCaptureSession) {
        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill
    }
}

private struct CameraPreviewNSViewRepresentable: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> CameraPreviewNSView {
        let view = CameraPreviewNSView(frame: .zero)
        view.setSession(session)
        return view
    }

    func updateNSView(_ nsView: CameraPreviewNSView, context: Context) {
        nsView.setSession(session)
    }
}
#endif

// MARK: - iOS (UIView + AVCaptureVideoPreviewLayer)
#if os(iOS)
private final class CameraPreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

    func setSession(_ session: AVCaptureSession) {
        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill
    }
}

private struct CameraPreviewUIViewRepresentable: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.setSession(session)
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        uiView.setSession(session)
    }
}
#endif
