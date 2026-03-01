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

    /// Body pose detector — receives each camera frame for real-time landmark detection.
    /// Use `setPoseDetector(_:)` to set this so the nonisolated delegate can access it.
    private(set) weak var poseDetector: BodyPoseDetector?

    func setPoseDetector(_ detector: BodyPoseDetector?) {
        poseDetector = detector
        cameraFeedStore.setDetector(detector)
    }

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
        cameraFeedStore.clearBuffer()
        sessionQueue.async { sessionToStop?.stopRunning() }
    }

    // MARK: - Frame capture

    /// Captures the most recent camera frame as a JPEG (≈100 KB). Returns nil if camera not running.
    func captureFrame() -> Data? {
        guard let pb = cameraFeedStore.getBuffer() else { return nil }
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
        #if os(macOS)
        // macOS: use default video device (e.g. FaceTime HD); no front/back
        let device = AVCaptureDevice.default(for: .video)
        #else
        let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
            ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            ?? AVCaptureDevice.default(for: .video)
        #endif
        guard let device else {
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
        cameraFeedStore.setBuffer(pb)

        // Run body pose detection on the frame
        cameraFeedStore.getDetector()?.detectPose(in: pb)
    }
}

// MARK: - Thread-safe storage (accessed from camera frame queue, not actor-isolated)

/// Lock-guarded storage for cross-thread access from the AVCapture delegate.
private final class CameraFeedStore: @unchecked Sendable {
    private let bufferLock = NSLock()
    private var latestBuffer: CVPixelBuffer?

    private let detectorLock = NSLock()
    private var poseDetector: BodyPoseDetector?

    func setBuffer(_ pb: CVPixelBuffer?) {
        bufferLock.lock()
        latestBuffer = pb
        bufferLock.unlock()
    }

    func getBuffer() -> CVPixelBuffer? {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        return latestBuffer
    }

    func clearBuffer() {
        bufferLock.lock()
        latestBuffer = nil
        bufferLock.unlock()
    }

    func setDetector(_ detector: BodyPoseDetector?) {
        detectorLock.lock()
        poseDetector = detector
        detectorLock.unlock()
    }

    func getDetector() -> BodyPoseDetector? {
        detectorLock.lock()
        defer { detectorLock.unlock() }
        return poseDetector
    }
}

/// Shared instance — safe to access from any thread/queue.
private let cameraFeedStore = CameraFeedStore()

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
