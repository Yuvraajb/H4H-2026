//
//  BodyPoseDetector.swift
//  Survivor MVP
//
//  Real-time body pose detection using Apple Vision framework.
//  Detects anatomical landmarks (wrists, neck, joints) and labels
//  medically relevant points like pulse locations on the camera feed.
//

import Vision
import SwiftUI
import CoreImage

// MARK: - Detected landmark with medical annotation

struct DetectedLandmark: Identifiable {
    let id = UUID()
    let name: String               // e.g. "Left Wrist"
    let medicalLabel: String?      // e.g. "Radial Pulse"
    let point: CGPoint             // normalized 0…1 (Vision coords: origin bottom-left)
    let confidence: Float
    let category: LandmarkCategory

    enum LandmarkCategory: String {
        case pulsePoint = "Pulse Point"
        case joint = "Joint"
        case head = "Head"
        case torso = "Torso"
    }
}

// MARK: - Thread-safe throttle (accessed from camera frame queue, not actor-isolated)

private final class PoseThrottle: @unchecked Sendable {
    private let lock = NSLock()
    private var lastTime: CFAbsoluteTime = 0
    let interval: CFAbsoluteTime = 0.1  // 10 fps cap

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
final class BodyPoseDetector {
    var detectedLandmarks: [DetectedLandmark] = []
    var isDetecting: Bool = false
    var showOverlay: Bool = true

    // nonisolated(unsafe): accessed from the camera frame queue via nonisolated detectPose;
    // thread-safety is handled internally by PoseThrottle's NSLock.
    @ObservationIgnored nonisolated(unsafe) private let throttle = PoseThrottle()

    // MARK: - Joint mappings (nonisolated static — not subject to @MainActor inference)

    nonisolated private static let jointMappings: [(VNHumanBodyPoseObservation.JointName, String, String?, DetectedLandmark.LandmarkCategory)] = [
        // Pulse points — most medically relevant
        (.leftWrist,    "Left Wrist",       "Radial Pulse",     .pulsePoint),
        (.rightWrist,   "Right Wrist",      "Radial Pulse",     .pulsePoint),
        (.neck,         "Neck",             "Carotid Pulse",    .pulsePoint),
        (.leftAnkle,    "Left Ankle",       "Pedal Pulse",      .pulsePoint),
        (.rightAnkle,   "Right Ankle",      "Pedal Pulse",      .pulsePoint),

        // Head
        (.nose,         "Nose",             "Airway",           .head),
        (.leftEye,      "Left Eye",         "Pupil Response",   .head),
        (.rightEye,     "Right Eye",        "Pupil Response",   .head),
        (.leftEar,      "Left Ear",         nil,                .head),
        (.rightEar,     "Right Ear",        nil,                .head),

        // Torso
        (.leftShoulder, "Left Shoulder",    nil,                .torso),
        (.rightShoulder,"Right Shoulder",   nil,                .torso),
        (.leftHip,      "Left Hip",         "Femoral Pulse",    .pulsePoint),
        (.rightHip,     "Right Hip",        "Femoral Pulse",    .pulsePoint),
        (.root,         "Root (Pelvis)",    nil,                .torso),

        // Joints with pulse-relevant labels
        (.leftElbow,    "Left Elbow",       "Brachial Pulse",   .pulsePoint),
        (.rightElbow,   "Right Elbow",      "Brachial Pulse",   .pulsePoint),
        (.leftKnee,     "Left Knee",        "Popliteal Pulse",  .pulsePoint),
        (.rightKnee,    "Right Knee",       "Popliteal Pulse",  .pulsePoint),
    ]

    nonisolated private static func extractLandmarks(from observation: VNHumanBodyPoseObservation) -> [DetectedLandmark] {
        var landmarks: [DetectedLandmark] = []
        for (jointName, name, medicalLabel, category) in jointMappings {
            guard let point = try? observation.recognizedPoint(jointName),
                  point.confidence > 0.3 else { continue }
            landmarks.append(DetectedLandmark(
                name: name,
                medicalLabel: medicalLabel,
                point: point.location,
                confidence: point.confidence,
                category: category
            ))
        }
        return landmarks
    }

    /// Process a pixel buffer from the camera and detect body pose landmarks.
    /// Called from the camera frame queue (nonisolated).
    nonisolated func detectPose(in pixelBuffer: CVPixelBuffer) {
        guard throttle.shouldProcess() else { return }

        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return
        }

        guard let observation = request.results?.first else {
            DispatchQueue.main.async { [weak self] in
                self?.detectedLandmarks = []
                self?.isDetecting = false
            }
            return
        }

        let landmarks = Self.extractLandmarks(from: observation)
        DispatchQueue.main.async { [weak self] in
            self?.detectedLandmarks = landmarks
            self?.isDetecting = !landmarks.isEmpty
        }
    }

    /// Returns a summary string of currently visible landmarks for AI context.
    var landmarkSummary: String? {
        guard !detectedLandmarks.isEmpty else { return nil }

        let pulsePoints = detectedLandmarks.filter { $0.category == .pulsePoint }
        let visible = detectedLandmarks.map { $0.name }.joined(separator: ", ")

        var summary = "Body pose detected. Visible: \(visible)."
        if !pulsePoints.isEmpty {
            let pulses = pulsePoints.compactMap { $0.medicalLabel }.uniqued()
            summary += " Accessible pulse points: \(pulses.joined(separator: ", "))."
        }
        return summary
    }
}

// MARK: - Array helper

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
