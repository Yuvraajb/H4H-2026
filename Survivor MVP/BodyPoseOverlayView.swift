//
//  BodyPoseOverlayView.swift
//  Survivor MVP
//
//  Renders detected body landmarks as labeled dots + connectors
//  overlaid on the live camera preview. Pulse points are highlighted
//  with a pulsing ring animation.
//

import SwiftUI

struct BodyPoseOverlayView: View {
    let landmarks: [DetectedLandmark]
    let showLabels: Bool
    let verifiedLandmarkName: String?

    init(landmarks: [DetectedLandmark], showLabels: Bool = true, verifiedLandmarkName: String? = nil) {
        self.landmarks = landmarks
        self.showLabels = showLabels
        self.verifiedLandmarkName = verifiedLandmarkName
    }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size

            // Skeleton connectors
            SkeletonLinesView(landmarks: landmarks, size: size)

            // Individual landmark dots + labels
            ForEach(landmarks) { landmark in
                let pos = convertPoint(landmark.point, in: size)
                let isVerified = verifiedLandmarkName == landmark.name

                LandmarkDotView(landmark: landmark, showLabel: showLabels, isVerified: isVerified)
                    .position(pos)
            }
        }
    }

    /// Convert Vision normalized coords (bottom-left origin) to SwiftUI (top-left origin).
    /// Also mirror horizontally for front camera.
    private func convertPoint(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(
            x: (1 - point.x) * size.width,  // mirror for front camera
            y: (1 - point.y) * size.height   // flip Y from bottom-left to top-left
        )
    }
}

// MARK: - Single landmark dot

private struct LandmarkDotView: View {
    let landmark: DetectedLandmark
    let showLabel: Bool
    let isVerified: Bool
    @State private var pulseAnimation = false

    private var dotColor: Color {
        if isVerified { return .green }
        switch landmark.category {
        case .pulsePoint: return .red
        case .joint:      return .cyan
        case .head:       return .yellow
        case .torso:      return .green
        }
    }

    private var dotSize: CGFloat {
        landmark.category == .pulsePoint ? 14 : 10
    }

    var body: some View {
        ZStack {
            // Pulse ring for pulse points
            if landmark.category == .pulsePoint {
                Circle()
                    .stroke(dotColor.opacity(0.5), lineWidth: 2)
                    .frame(width: dotSize + 12, height: dotSize + 12)
                    .scaleEffect(pulseAnimation ? 1.6 : 1.0)
                    .opacity(pulseAnimation ? 0.0 : 0.7)
                    .animation(
                        .easeOut(duration: 1.2).repeatForever(autoreverses: false),
                        value: pulseAnimation
                    )
                    .onAppear { pulseAnimation = true }
            }

            // Core dot
            Circle()
                .fill(dotColor)
                .frame(width: dotSize, height: dotSize)
                .shadow(color: dotColor.opacity(0.6), radius: 4)

            // Confidence ring
            Circle()
                .stroke(dotColor.opacity(0.8), lineWidth: 1.5)
                .frame(width: dotSize + 4, height: dotSize + 4)

            // Verified checkmark
            if isVerified {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.green)
                    .shadow(color: .green.opacity(0.6), radius: 6)
                    .offset(x: 12, y: -12)
            }

            // Label
            if showLabel {
                VStack(spacing: 1) {
                    Text(landmark.medicalLabel ?? landmark.name)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    if landmark.medicalLabel != nil {
                        Text(landmark.name)
                            .font(.system(size: 7, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(dotColor.opacity(0.75), in: RoundedRectangle(cornerRadius: 4))
                .offset(y: -22)
            }
        }
    }
}

// MARK: - Skeleton connector lines

private struct SkeletonLinesView: View {
    let landmarks: [DetectedLandmark]
    let size: CGSize

    /// Pairs of landmark names that should be connected by lines.
    private let connections: [(String, String)] = [
        // Torso
        ("Left Shoulder", "Right Shoulder"),
        ("Left Shoulder", "Left Hip"),
        ("Right Shoulder", "Right Hip"),
        ("Left Hip", "Right Hip"),

        // Left arm
        ("Left Shoulder", "Left Elbow"),
        ("Left Elbow", "Left Wrist"),

        // Right arm
        ("Right Shoulder", "Right Elbow"),
        ("Right Elbow", "Right Wrist"),

        // Left leg
        ("Left Hip", "Left Knee"),
        ("Left Knee", "Left Ankle"),

        // Right leg
        ("Right Hip", "Right Knee"),
        ("Right Knee", "Right Ankle"),

        // Head
        ("Neck", "Nose"),
        ("Left Shoulder", "Neck"),
        ("Right Shoulder", "Neck"),
    ]

    var body: some View {
        Canvas { context, _ in
            let landmarkDict = Dictionary(uniqueKeysWithValues: landmarks.map { ($0.name, $0) })

            for (nameA, nameB) in connections {
                guard let a = landmarkDict[nameA],
                      let b = landmarkDict[nameB] else { continue }

                let posA = convertPoint(a.point, in: size)
                let posB = convertPoint(b.point, in: size)

                var path = Path()
                path.move(to: posA)
                path.addLine(to: posB)

                context.stroke(
                    path,
                    with: .color(.white.opacity(0.3)),
                    lineWidth: 1.5
                )
            }
        }
    }

    private func convertPoint(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(
            x: (1 - point.x) * size.width,
            y: (1 - point.y) * size.height
        )
    }
}

// MARK: - Detection status badge (top-right of camera)

struct PoseDetectionBadge: View {
    let landmarkCount: Int
    let pulsePointCount: Int
    let isDetecting: Bool

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isDetecting ? Color.green : Color.gray)
                .frame(width: 6, height: 6)
            VStack(alignment: .leading, spacing: 1) {
                Text(isDetecting ? "BODY DETECTED" : "NO BODY")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(0.5)
                if isDetecting {
                    Text("\(landmarkCount) points · \(pulsePointCount) pulse")
                        .font(.system(size: 7, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 6))
    }
}
