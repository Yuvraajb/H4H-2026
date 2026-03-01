//
//  CameraFeedModel.swift
//  Survivor MVP
//
//  Camera authorization and AVCaptureSession for live preview in Visual guide.
//  On macOS/iOS: also captures frames for person detection (Vision) and optional snapshot for AI.
//  visionOS: preview only; no frame capture.
//

@preconcurrency import AVFoundation
import SwiftUI
#if !os(visionOS)
import CoreImage
import ImageIO
import UniformTypeIdentifiers
import Vision
#endif

@MainActor
@Observable
final class CameraFeedModel {
    enum Status: Equatable {
        case idle
        case requestingPermission
        case unauthorized
        case unavailable
        case running
        case failed(String)
    }

    private let sessionQueue = DispatchQueue(label: "com.pulsecoach.camera.session")

    var status: Status = .idle
    var session: AVCaptureSession?

    /// True when at least one person is detected in the latest throttled Vision run. visionOS: always false.
    var personDetected: Bool = false

    #if !os(visionOS)
    private var videoDataOutput: AVCaptureVideoDataOutput?
    private var lastFrameJPEGData: Data?
    private var lastDetectionTime: Date = .distantPast
    private let detectionInterval: TimeInterval = 1.0
    #endif

    func start() {
        status = .requestingPermission

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStartSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    if granted {
                        self.configureAndStartSession()
                    } else {
                        self.status = .unauthorized
                    }
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
        personDetected = false
        #if !os(visionOS)
        videoDataOutput = nil
        lastFrameJPEGData = nil
        #endif
        sessionQueue.async { [sessionToStop] in
            sessionToStop?.stopRunning()
        }
    }

    /// Returns the latest frame as JPEG data (updated ~1/sec when camera runs), or nil if unavailable (e.g. visionOS or no frame yet).
    func captureCurrentFrame() -> Data? {
        #if os(visionOS)
        return nil
        #else
        return lastFrameJPEGData
        #endif
    }

    /// Returns the latest frame as base64-encoded JPEG, or nil if unavailable. Use for vision API (e.g. Analyze what I see).
    func captureJPEGBase64() -> String? {
        guard let data = captureCurrentFrame() else { return nil }
        return data.base64EncodedString()
    }

    #if !os(visionOS)
    private func resizeCGImage(_ image: CGImage, width: Int, height: Int) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: colorSpace, bitmapInfo: bitmapInfo) else { return nil }
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    private func compressJPEG(cgImage: CGImage, quality: CGFloat) -> Data? {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, "public.jpeg" as CFString, 1, nil) else { return nil }
        let options: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: quality]
        CGImageDestinationAddImage(dest, cgImage, options as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return data as Data
    }
    #endif

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
            if newSession.canAddInput(input) {
                newSession.addInput(input)
            }
            #if !os(visionOS)
            newSession.sessionPreset = .high
            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            output.setSampleBufferDelegate(CameraFrameDelegate(owner: self), queue: sessionQueue)
            if newSession.canAddOutput(output) {
                newSession.addOutput(output)
                videoDataOutput = output
            }
            #endif
        } catch {
            newSession.commitConfiguration()
            status = .failed(error.localizedDescription)
            return
        }

        newSession.commitConfiguration()
        self.session = newSession

        sessionQueue.async { [weak self, newSession] in
            newSession.startRunning()
            DispatchQueue.main.async { [weak self] in
                self?.status = .running
            }
        }
    }

    #if !os(visionOS)
    fileprivate func didCaptureSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        let now = Date()
        let shouldRun = now.timeIntervalSince(lastDetectionTime) >= detectionInterval
        guard shouldRun, let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastDetectionTime = now
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        let maxWidth: CGFloat = 640
        let scale = min(1, maxWidth / CGFloat(cgImage.width))
        let newWidth = Int(CGFloat(cgImage.width) * scale)
        let newHeight = Int(CGFloat(cgImage.height) * scale)
        if newWidth > 0, newHeight > 0,
           let scaled = resizeCGImage(cgImage, width: newWidth, height: newHeight),
           let jpeg = compressJPEG(cgImage: scaled, quality: 0.7) {
            lastFrameJPEGData = jpeg
        }
        let request = VNDetectHumanRectanglesRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        do {
            try handler.perform([request])
            let results = (request.results as? [VNHumanObservation]) ?? []
            personDetected = !results.isEmpty
        } catch {
            personDetected = false
        }
    }
    #endif
}

#if !os(visionOS)
private final class CameraFrameDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private weak var owner: CameraFeedModel?

    init(owner: CameraFeedModel) {
        self.owner = owner
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        Task { @MainActor in
            owner?.didCaptureSampleBuffer(sampleBuffer)
        }
    }
}
#endif
