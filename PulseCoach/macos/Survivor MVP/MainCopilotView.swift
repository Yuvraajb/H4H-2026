//
//  MainCopilotView.swift
//  Survivor MVP
//
//  Center panel: chat + steps, current step card, transcript/response feed, text input.
//

import SwiftUI

struct MainCopilotView: View {
    @Environment(PulseCoachModel.self) private var model
    @State private var inputText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            switch model.state {
            case .blankReady:
                blankReadyContent
            case .copilotActive:
                copilotActiveContent
            case .resolved:
                resolvedContent
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .modifier(PanelBackgroundModifier())
    }

    private var blankReadyContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("First Aid Copilot")
                .font(.title2)
                .fontWeight(.semibold)
            Text("PulseCoach will guide you through checking responsiveness, breathing, and pulse, then recommend next steps. When you're ready, tap **Start Copilot** in the left panel.")
                .font(.body)
                .foregroundStyle(.secondary)
            Button(action: { model.startCopilot() }) {
                Label("Start", systemImage: "play.fill")
                    .font(.title3)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private var copilotActiveContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            currentStepCard
            transcriptAndResponses
            inputBar
        }
    }

    private var currentStepCard: some View {
        Group {
            if model.steps.isEmpty {
                Text("Loading steps…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if model.selectedStepIndex >= 0, model.selectedStepIndex < model.steps.count {
                let step = model.steps[model.selectedStepIndex]
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current Step")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(step.title)
                        .font(.headline)
                    Text(step.detail)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private var transcriptAndResponses: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Conversation")
                .font(.caption)
                .foregroundStyle(.secondary)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(zip(model.transcript.indices, model.transcript)), id: \.0) { _, msg in
                        transcriptBubble(msg, isUser: true)
                    }
                    ForEach(Array(zip(model.responses.indices, model.responses)), id: \.0) { _, msg in
                        transcriptBubble(msg, isUser: false)
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 200)
        }
    }

    private func transcriptBubble(_ text: String, isUser: Bool) -> some View {
        HStack {
            if isUser { Spacer(minLength: 40) }
            Text(text)
                .font(.subheadline)
                .padding(10)
                .background(isUser ? Color.accentColor.opacity(0.2) : Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            if !isUser { Spacer(minLength: 40) }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField("Type to simulate voice…", text: $inputText)
                .textFieldStyle(.roundedBorder)
            Button("Send") {
                sendInput()
            }
            .buttonStyle(.borderedProminent)
            .disabled(inputText.isEmpty)
        }
    }

    private func sendInput() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        model.addUserUtterance(text)
        inputText = ""
        let step = model.steps.indices.contains(model.selectedStepIndex)
            ? model.steps[model.selectedStepIndex]
            : nil
        let response = step.map { "Got it. Next, do this: \($0.title). \($0.detail)" }
            ?? "Got it. Follow the steps on the left."
        model.addAIResponse(response)
    }

    private var resolvedContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Session complete")
                .font(.title2)
                .fontWeight(.semibold)
            Text("You've gone through the triage flow. Use **Reset** in the left panel to start over.")
                .font(.body)
                .foregroundStyle(.secondary)
            Button(action: { model.reset() }) {
                Label("Reset", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

#Preview {
    MainCopilotView()
        .environment(PulseCoachModel())
        .frame(minWidth: 520, minHeight: 400)
}
