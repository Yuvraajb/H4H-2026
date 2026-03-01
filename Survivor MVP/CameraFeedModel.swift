//
//  CameraFeedModel.swift
//  Survivor MVP
//
//  Live camera feed + on-demand JPEG frame capture for vision AI.
//

@preconcurrency import AVFoundation
import SwiftUI
#if os(macOS)
import AppKit
#endif

@MainActor
@Observable
final class CameraFeedModel: NSObject {
    enum Status: Equatable {
        case idle
        case requestingPermission
        case unauthorized
        case unavailable
        case running
        case failed(String)
    }

    private let sessionQueue = DispatchQueue(label: "com.personaldoctor.camera.session")
    private let frameQueue  = DispatchQueue(label: "com.personaldoctor.camera.frame")

    var status: Status = .idle
    var session: AVCaptureSession?

    private var latestPixelBuffer: CVPixelBuffer?

    // MARK: - Session control

    func start() {
        status = .requestingPermission
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStartSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    if granted { self.configureAndStartSession() } else { self.status = .unauthorized }
                }
            }
        case .denied, .restricted:
            status = .unauthorized
        @unknown default:
            status = .unauthorized
        }
    }

    func stop() {
        let sessionToStop = session
        session = nil
        status = .idle
        latestPixelBuffer = nil
        sessionQueue.async { sessionToStop?.stopRunning() }
    }

    // MARK: - Frame capture

    /// Captures the most recent camera frame as a JPEG (≈100 KB). Returns nil if camera not running.
    func captureFrame() -> Data? {
        guard let pb = latestPixelBuffer else { return nil }
        #if os(macOS)
        let ci = CIImage(cvPixelBuffer: pb)
        guard let cg = CIContext().createCGImage(ci, from: ci.extent) else { return nil }
        // Scale down to max 640px wide to keep payload small
        let original = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
        let scaled = original.resized(toMaxWidth: 640)
        return scaled.jpegData(compressionQuality: 0.5)
        #else
        return nil
        #endif
    }

    // MARK: - Private

    private func configureAndStartSession() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
            ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            ?? AVCaptureDevice.default(for: .video) else {
            status = .unavailable
            return
        }

        let newSession = AVCaptureSession()
        newSession.beginConfiguration()

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if newSession.canAddInput(input) { newSession.addInput(input) }
            #if !os(visionOS)
            newSession.sessionPreset = .high
            #endif
        } catch {
            newSession.commitConfiguration()
            status = .failed(error.localizedDescription)
            return
        }

        // Video data output for frame capture
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: frameQueue)
        if newSession.canAddOutput(videoOutput) { newSession.addOutput(videoOutput) }

        newSession.commitConfiguration()
        self.session = newSession

        sessionQueue.async { [weak self, newSession] in
            newSession.startRunning()
            DispatchQueue.main.async { self?.status = .running }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraFeedModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pb = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        // Store on main actor — dispatch to avoid crossing isolation boundary directly
        let retained = pb
        Task { @MainActor [weak self] in self?.latestPixelBuffer = retained }
    }
}

// MARK: - NSImage JPEG helper

#if os(macOS)
private extension NSImage {
    func resized(toMaxWidth maxWidth: CGFloat) -> NSImage {
        let w = size.width, h = size.height
        guard w > maxWidth else { return self }
        let scale = maxWidth / w
        let newSize = NSSize(width: maxWidth, height: h * scale)
        let img = NSImage(size: newSize)
        img.lockFocus()
        draw(in: NSRect(origin: .zero, size: newSize),
             from: NSRect(origin: .zero, size: size),
             operation: .copy, fraction: 1)
        img.unlockFocus()
        return img
    }

    func jpegData(compressionQuality: CGFloat) -> Data? {
        guard let tiff = tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality])
    }
}
#endif
