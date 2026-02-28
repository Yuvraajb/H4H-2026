//
//  LeftRailView.swift
//  Survivor MVP
//
//  Left sidebar: title, status, input mode toggle, primary action, quick actions, steps list.
//

import SwiftUI

struct LeftRailView: View {
    @Environment(PulseCoachModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            titleAndStatus
            inputModeToggle
            primaryButton
            if model.state == .copilotActive {
                quickActions
                stepsList
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(PanelBackgroundModifier())
    }

    private var titleAndStatus: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PulseCoach")
                .font(.title)
                .fontWeight(.bold)
            statusPill
        }
    }

    private var statusPill: some View {
        Text(statusLabel)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.3), in: Capsule())
    }

    private var statusLabel: String {
        switch model.state {
        case .blankReady: return "Blank"
        case .copilotActive: return "Active"
        case .resolved: return "Resolved"
        }
    }

    private var statusColor: Color {
        switch model.state {
        case .blankReady: return .secondary
        case .copilotActive: return .green
        case .resolved: return .blue
        }
    }

    private var inputModeToggle: some View {
        Picker("Input", selection: Binding(
            get: { model.inputMode },
            set: { model.inputMode = $0 }
        )) {
            Text("Voice").tag(InputMode.voice)
            Text("Touch").tag(InputMode.touch)
        }
        .pickerStyle(.segmented)
    }

    private var primaryButton: some View {
        Group {
            switch model.state {
            case .blankReady:
                Button(action: { model.startCopilot() }) {
                    Label("Start Copilot", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
            case .copilotActive:
                Button(action: simulateVoiceInput) {
                    Label("Add Voice Input (Simulate)", systemImage: "mic.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
            case .resolved:
                Button(action: { model.reset() }) {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .controlSize(.large)
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick actions")
                .font(.headline)
            HStack(spacing: 8) {
                Button("Next Step", action: { model.nextStep() })
                    .buttonStyle(.bordered)
                Button("Previous", action: { model.previousStep() })
                    .buttonStyle(.bordered)
            }
            Button("Repeat", action: { model.repeatCurrentStep() })
                .buttonStyle(.bordered)
            Button("Mark resolved", action: { model.markResolved() })
                .buttonStyle(.bordered)
        }
    }

    private var stepsList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Steps")
                .font(.headline)
            if model.steps.isEmpty {
                Text("No steps")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(model.steps.enumerated()), id: \.element.id) { index, step in
                    stepRow(index: index, step: step)
                }
            }
        }
    }

    private func stepRow(index: Int, step: InstructionStep) -> some View {
        let isSelected = index == model.selectedStepIndex
        return Button(action: {
            model.selectedStepIndex = min(max(index, 0), model.steps.count - 1)
        }) {
            HStack(spacing: 8) {
                Text("\(index + 1).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(step.title)
                    .font(.subheadline)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func simulateVoiceInput() {
        model.addUserUtterance("(Simulated voice input)")
        let step = model.steps.indices.contains(model.selectedStepIndex)
            ? model.steps[model.selectedStepIndex]
            : nil
        let response = step.map { "Got it. Next, do this: \($0.title). \($0.detail)" }
            ?? "Got it. Follow the steps on the left."
        model.addAIResponse(response)
    }
}

#Preview {
    LeftRailView()
        .environment(PulseCoachModel())
        .frame(width: 280)
}
