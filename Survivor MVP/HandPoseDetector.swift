//
//  HandPoseDetector.swift
//  Survivor MVP
//
//  Real-time hand pose detection using Apple Vision framework.
//  Extracts fingertip and palm positions for action verification
//  (pulse check, CPR placement, airway maneuver, etc.).
//

import Vision
import SwiftUI

// MARK: - Hand landmarks

struct HandLandmarks: Equatable {
    let indexTip: CGPoint      // normalized 0…1 (Vision coords: origin bottom-left)
    let middleTip: CGPoint
    let thumbTip: CGPoint
    let wrist: CGPoint
    let palmCenter: CGPoint    // midpoint of middle MCP + wrist

    static func == (lhs: HandLandmarks, rhs: HandLandmarks) -> Bool {
        lhs.indexTip == rhs.indexTip &&
        lhs.middleTip == rhs.middleTip &&
        lhs.wrist == rhs.wrist
    }
}

// MARK: - Throttle (5 fps for hand detection)

private final class HandThrottle: @unchecked Sendable {
    private let lock = NSLock()
    private var lastTime: CFAbsoluteTime = 0
    let interval: CFAbsoluteTime = 0.2  // 5 fps cap

    func shouldProcess() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastTime >= interval else { return false }
        lastTime = now
        return true
    }
}

// MARK: - Detector

@Observable
final class HandPoseDetector {
    var detectedHands: [HandLandmarks] = []
    var isDetecting: Bool = false

    @ObservationIgnored nonisolated(unsafe) private let throttle = HandThrottle()

    /// Process a pixel buffer from the camera and detect hand poses.
    /// Called from the camera frame queue (nonisolated).
    nonisolated func detectHands(in pixelBuffer: CVPixelBuffer) {
        guard throttle.shouldProcess() else { return }

        let request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 2
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return
        }

        guard let observations = request.results, !observations.isEmpty else {
            DispatchQueue.main.async { [weak self] in
                self?.detectedHands = []
                self?.isDetecting = false
            }
            return
        }

        let hands = observations.compactMap { Self.extractLandmarks(from: $0) }
        DispatchQueue.main.async { [weak self] in
            self?.detectedHands = hands
            self?.isDetecting = !hands.isEmpty
        }
    }

    // MARK: - Extraction

    nonisolated private static func extractLandmarks(from observation: VNHumanHandPoseObservation) -> HandLandmarks? {
        guard let indexTip = try? observation.recognizedPoint(.indexTip),
              let middleTip = try? observation.recognizedPoint(.middleTip),
              let thumbTip = try? observation.recognizedPoint(.thumbTip),
              let wrist = try? observation.recognizedPoint(.wrist),
              let middleMCP = try? observation.recognizedPoint(.middleMCP),
              indexTip.confidence > 0.3,
              wrist.confidence > 0.3 else {
            return nil
        }

        let palmCenter = CGPoint(
            x: (middleMCP.location.x + wrist.location.x) / 2,
            y: (middleMCP.location.y + wrist.location.y) / 2
        )

        return HandLandmarks(
            indexTip: indexTip.location,
            middleTip: middleTip.location,
            thumbTip: thumbTip.location,
            wrist: wrist.location,
            palmCenter: palmCenter
        )
    }
}
