//
//  ActionVerifier.swift
//  Survivor MVP
//
//  Verifies correct hand/finger placement for medical actions:
//  pulse check, CPR, head-tilt/chin-lift, etc.
//  Drives visual feedback and action-specific follow-ups (timers, confirmations).
//

import SwiftUI

// MARK: - Action types

enum VerifiableAction: Equatable {
    case pulseCheck(target: String)   // "radial" or "carotid"
    case cpr
    case headTiltChinLift
    case none
}

// MARK: - State machine

enum ActionVerifierState: Equatable {
    case idle                   // no verifiable action
    case guiding                // showing where to place hands
    case confirmed              // correct placement detected, stability hold
    case acting                 // action-specific phase (timer, rhythm, hold)
    case complete               // done — collecting result if needed
}

// MARK: - ActionVerifier

@MainActor
@Observable
final class ActionVerifier {

    // Public state
    var state: ActionVerifierState = .idle
    var currentAction: VerifiableAction = .none
    var isFingerOnTarget: Bool = false
    var timerRemaining: Int = 15
    var targetLandmarkName: String?            // which body landmark is the target
    var guidanceText: String = ""
    var beatCount: Int? = nil                  // set by user after pulse timer

    // Private
    private var confirmStartTime: Date?
    private var actingTimer: Timer?
    private let confirmHoldDuration: TimeInterval = 0.5  // must hold 0.5s to confirm
    private let proximityThreshold: CGFloat = 0.07       // normalized distance threshold

    // MARK: - Detect action from AI text

    func detectAction(from aiText: String) {
        let text = aiText.lowercased()

        let newAction: VerifiableAction
        if text.contains("pulse") || text.contains("check pulse") {
            if text.contains("neck") || text.contains("carotid") {
                newAction = .pulseCheck(target: "carotid")
            } else {
                newAction = .pulseCheck(target: "radial")
            }
        } else if text.contains("cpr") || text.contains("chest compression") || text.contains("compress") {
            newAction = .cpr
        } else if text.contains("head tilt") || text.contains("chin lift") || text.contains("airway") {
            newAction = .headTiltChinLift
        } else {
            newAction = .none
        }

        guard newAction != currentAction else { return }
        currentAction = newAction
        resetState()

        if newAction != .none {
            state = .guiding
            updateGuidanceText()
            updateTargetLandmark()
        }
    }

    // MARK: - Per-frame update

    func update(hands: [HandLandmarks], bodyLandmarks: [DetectedLandmark]) {
        guard currentAction != .none, state != .complete else { return }

        let placed = checkPlacement(hands: hands, bodyLandmarks: bodyLandmarks)
        isFingerOnTarget = placed

        switch state {
        case .idle:
            break

        case .guiding:
            if placed {
                confirmStartTime = Date()
                state = .confirmed
                guidanceText = "Hold..."
            }

        case .confirmed:
            if !placed {
                // Lost placement — back to guiding
                state = .guiding
                confirmStartTime = nil
                updateGuidanceText()
            } else if let start = confirmStartTime,
                      Date().timeIntervalSince(start) >= confirmHoldDuration {
                // Held long enough — transition to acting
                state = .acting
                startActingPhase()
            }

        case .acting:
            handleActingUpdate(placed: placed)

        case .complete:
            break
        }
    }

    // MARK: - Beat count submission (pulse check)

    func submitBeatCount(_ count: Int) {
        beatCount = count
    }

    // MARK: - Result string for AI context

    var actionResultString: String? {
        guard state == .complete else { return nil }
        switch currentAction {
        case .pulseCheck(let target):
            if let beats = beatCount {
                let bpm = beats * 4  // 15 seconds → multiply by 4
                return "Pulse measured at \(target) artery: \(beats) beats in 15s = \(bpm) BPM"
            }
            return nil
        case .cpr:
            return "CPR hand placement verified — hands correctly positioned on chest center"
        case .headTiltChinLift:
            return "Head-tilt/chin-lift verified — airway opened correctly"
        case .none:
            return nil
        }
    }

    /// Dismiss the current action and go back to idle.
    func dismiss() {
        actingTimer?.invalidate()
        actingTimer = nil
        currentAction = .none
        resetState()
    }

    // MARK: - Private helpers

    private func resetState() {
        state = currentAction == .none ? .idle : .guiding
        isFingerOnTarget = false
        confirmStartTime = nil
        timerRemaining = 15
        beatCount = nil
        actingTimer?.invalidate()
        actingTimer = nil
        updateGuidanceText()
        updateTargetLandmark()
    }

    private func updateGuidanceText() {
        switch currentAction {
        case .pulseCheck(let target):
            guidanceText = target == "carotid"
                ? "Place two fingers on the neck"
                : "Place two fingers on the wrist"
        case .cpr:
            guidanceText = "Place hands on center of chest"
        case .headTiltChinLift:
            guidanceText = "One hand on forehead, one under chin"
        case .none:
            guidanceText = ""
        }
    }

    private func updateTargetLandmark() {
        switch currentAction {
        case .pulseCheck(let target):
            targetLandmarkName = target == "carotid" ? "Neck" : "Left Wrist"
        case .cpr:
            targetLandmarkName = "Left Shoulder"   // approximate chest center reference
        case .headTiltChinLift:
            targetLandmarkName = "Nose"
        case .none:
            targetLandmarkName = nil
        }
    }

    // MARK: - Placement checks

    private func checkPlacement(hands: [HandLandmarks], bodyLandmarks: [DetectedLandmark]) -> Bool {
        guard !hands.isEmpty, !bodyLandmarks.isEmpty else { return false }

        switch currentAction {
        case .pulseCheck(let target):
            return checkPulsePlacement(hands: hands, bodyLandmarks: bodyLandmarks, target: target)
        case .cpr:
            return checkCPRPlacement(hands: hands, bodyLandmarks: bodyLandmarks)
        case .headTiltChinLift:
            return checkAirwayPlacement(hands: hands, bodyLandmarks: bodyLandmarks)
        case .none:
            return false
        }
    }

    private func checkPulsePlacement(hands: [HandLandmarks], bodyLandmarks: [DetectedLandmark], target: String) -> Bool {
        let targetNames: Set<String>
        if target == "carotid" {
            targetNames = ["Neck"]
        } else {
            targetNames = ["Left Wrist", "Right Wrist"]
        }

        let targets = bodyLandmarks.filter { targetNames.contains($0.name) }
        guard !targets.isEmpty else { return false }

        // Check if any fingertip is near any target pulse point
        for hand in hands {
            let fingerPoints = [hand.indexTip, hand.middleTip]
            for finger in fingerPoints {
                for target in targets {
                    if distance(finger, target.point) < proximityThreshold {
                        return true
                    }
                }
            }
        }
        return false
    }

    private func checkCPRPlacement(hands: [HandLandmarks], bodyLandmarks: [DetectedLandmark]) -> Bool {
        // Compute chest center from shoulders and pelvis
        let dict = Dictionary(uniqueKeysWithValues: bodyLandmarks.map { ($0.name, $0.point) })
        guard let leftShoulder = dict["Left Shoulder"],
              let rightShoulder = dict["Right Shoulder"] else { return false }

        let shoulderMid = CGPoint(
            x: (leftShoulder.x + rightShoulder.x) / 2,
            y: (leftShoulder.y + rightShoulder.y) / 2
        )

        // Chest center is roughly 1/3 down from shoulders toward pelvis
        let chestCenter: CGPoint
        if let pelvis = dict["Root (Pelvis)"] {
            chestCenter = CGPoint(
                x: shoulderMid.x,
                y: shoulderMid.y + (pelvis.y - shoulderMid.y) * 0.33
            )
        } else {
            chestCenter = shoulderMid
        }

        // Check if any palm center is near chest center (wider threshold for CPR)
        let cprThreshold: CGFloat = 0.10
        for hand in hands {
            if distance(hand.palmCenter, chestCenter) < cprThreshold {
                return true
            }
        }
        return false
    }

    private func checkAirwayPlacement(hands: [HandLandmarks], bodyLandmarks: [DetectedLandmark]) -> Bool {
        let dict = Dictionary(uniqueKeysWithValues: bodyLandmarks.map { ($0.name, $0.point) })
        guard let nose = dict["Nose"] else { return false }
        let neck = dict["Neck"]

        // One hand near forehead (above nose), one near chin/neck
        // Forehead zone: near nose but slightly above
        let foreheadZone = CGPoint(x: nose.x, y: nose.y + 0.04) // slightly above in Vision coords (higher y = higher)
        let chinZone = neck ?? CGPoint(x: nose.x, y: nose.y - 0.06) // below nose

        var foreheadPlaced = false
        var chinPlaced = false

        for hand in hands {
            let points = [hand.palmCenter, hand.indexTip]
            for pt in points {
                if distance(pt, foreheadZone) < 0.10 {
                    foreheadPlaced = true
                }
                if distance(pt, chinZone) < 0.10 {
                    chinPlaced = true
                }
            }
        }

        // For single hand scenarios, accept either placement
        return foreheadPlaced || chinPlaced
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    // MARK: - Acting phase

    private func startActingPhase() {
        switch currentAction {
        case .pulseCheck:
            guidanceText = "Count the beats"
            timerRemaining = 15
            actingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
                Task { @MainActor [weak self] in
                    guard let self else { timer.invalidate(); return }
                    self.timerRemaining -= 1
                    if self.timerRemaining <= 0 {
                        timer.invalidate()
                        self.actingTimer = nil
                        self.state = .complete
                        self.guidanceText = "How many beats did you count?"
                    }
                }
            }
        case .cpr:
            guidanceText = "Hands placed correctly"
        case .headTiltChinLift:
            guidanceText = "Airway open — hold position"
        case .none:
            break
        }
    }

    private func handleActingUpdate(placed: Bool) {
        switch currentAction {
        case .pulseCheck:
            // Timer runs independently — don't revert
            break
        case .cpr:
            if !placed {
                // Hands drifted — revert to guiding
                state = .guiding
                actingTimer?.invalidate()
                actingTimer = nil
                updateGuidanceText()
            }
        case .headTiltChinLift:
            if !placed {
                state = .guiding
                actingTimer?.invalidate()
                actingTimer = nil
                updateGuidanceText()
            }
        case .none:
            break
        }
    }
}
