//
//  PulseCoachModel.swift
//  Survivor MVP
//
//  PulseCoach — First Aid Copilot: app state, steps, and chat transcript.
//

import SwiftUI

enum AppState: String, CaseIterable {
    case blankReady
    case copilotActive
    case resolved
}

enum InputMode: String, CaseIterable {
    case voice
    case touch
}

enum ImageHint: String, CaseIterable {
    case none
    case pulseRadial
    case pulseCarotid
    case recoveryPosition
    case cprHands
    case call911
}

struct InstructionStep: Identifiable {
    let id = UUID()
    var title: String
    var detail: String
    var imageHint: ImageHint
}

@MainActor
@Observable
class PulseCoachModel {
    var state: AppState = .blankReady
    var inputMode: InputMode = .voice
    var transcript: [String] = []
    var responses: [String] = []
    var steps: [InstructionStep] = []
    var selectedStepIndex: Int = 0

    var currentImageHint: ImageHint {
        guard !steps.isEmpty, selectedStepIndex >= 0, selectedStepIndex < steps.count else {
            return .none
        }
        return steps[selectedStepIndex].imageHint
    }

    func startCopilot() {
        state = .copilotActive
        transcript = []
        responses = []
        selectedStepIndex = 0
        steps = Self.defaultTriageSteps()
    }

    func addUserUtterance(_ text: String) {
        guard !text.isEmpty else { return }
        transcript.append(text)
    }

    func addAIResponse(_ text: String) {
        guard !text.isEmpty else { return }
        responses.append(text)
    }

    func nextStep() {
        guard selectedStepIndex < steps.count - 1 else { return }
        selectedStepIndex += 1
    }

    func previousStep() {
        guard selectedStepIndex > 0 else { return }
        selectedStepIndex -= 1
    }

    /// Stub: re-add current step text into responses (simulates "Repeat").
    func repeatCurrentStep() {
        guard selectedStepIndex >= 0, selectedStepIndex < steps.count else { return }
        let step = steps[selectedStepIndex]
        responses.append("Repeat: \(step.title). \(step.detail)")
    }

    func reset() {
        state = .blankReady
        inputMode = .voice
        transcript = []
        responses = []
        steps = []
        selectedStepIndex = 0
    }

    func markResolved() {
        state = .resolved
    }

    private static func defaultTriageSteps() -> [InstructionStep] {
        [
            InstructionStep(
                title: "Check responsiveness",
                detail: "Tap shoulders. Shout \"Are you okay?\" Look for movement, sound, or eyes opening.",
                imageHint: .none
            ),
            InstructionStep(
                title: "Check breathing (10s)",
                detail: "Look for chest rise. Listen for breath. Normal breathing = regular rise and fall. Gasping is not normal.",
                imageHint: .none
            ),
            InstructionStep(
                title: "Check radial pulse (15s)",
                detail: "Place two fingers on the inside of the wrist, below the base of the thumb. Count for 15 seconds.",
                imageHint: .pulseRadial
            ),
            InstructionStep(
                title: "If not breathing / no pulse → start CPR",
                detail: "Place heel of one hand on center of chest, other hand on top. Push hard and fast, 100–120 per minute.",
                imageHint: .cprHands
            ),
            InstructionStep(
                title: "Call emergency services",
                detail: "Call 911. Say: location, breathing status, pulse status. Stay on the line until help arrives.",
                imageHint: .call911
            ),
        ]
    }
}
