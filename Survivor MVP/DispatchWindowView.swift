//
//  DispatchWindowView.swift
//  Survivor MVP
//
//  First Responder dashboard — Dispatch panel: chat with emergency services.
//

import SwiftUI

struct DispatchWindowView: View {
    @Environment(CrisisCopilotModel.self) private var model
    @FocusState private var isComposerFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if model.state == .active {
                emergencyModePill
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 4)
            }
            VStack(spacing: 0) {
                header
                if model.state == .idle {
                    Button(action: { model.startEmergency() }) {
                        Label("Start emergency", systemImage: "play.fill")
                            .font(.subheadline)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.emergencyPrimary)
                    .padding(12)
                }
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            ForEach(model.messages) { msg in
                                DispatchMessageBubble(message: msg)
                                    .id(msg.id)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    .onChange(of: model.messages.count) { _, _ in
                        if let last = model.messages.last {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
                composerBar
            }
            .modifier(PanelBackgroundModifier())
        }
        .padding(12)
        .frame(minWidth: 320, minHeight: 400)
    }

    private var emergencyModePill: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.octagon.fill")
                .font(.caption)
                .foregroundStyle(Color.emergencyPrimary)
            Text("EMERGENCY MODE ACTIVE")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private var header: some View {
        HStack(alignment: .center) {
            HStack(spacing: 10) {
                ZStack(alignment: .bottomTrailing) {
                    Image(systemName: "person.wave.2.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.emergencySecondary, in: Circle())
                    Circle()
                        .fill(Color.green)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(.background, lineWidth: 2))
                        .offset(x: 2, y: 2)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dispatch")
                        .font(.headline)
                        .fontWeight(.bold)
                    connectionDurationText
                }
            }
            Spacer(minLength: 0)
            Button(action: {}) {
                Image(systemName: "ellipsis")
                    .font(.body)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial.opacity(0.5))
    }

    @ViewBuilder
    private var connectionDurationText: some View {
        if let since = model.dispatchConnectedSince {
            TimelineView(.periodic(from: since, by: 1.0)) { context in
                let elapsed = Int(context.date.timeIntervalSince(since))
                let m = elapsed / 60
                let s = elapsed % 60
                Text("Connected • \(String(format: "%02d:%02d", m, s))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
            Text("Not connected")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var composerBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            Button(action: { model.simulateVoiceInput() }) {
                Image(systemName: "mic.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.emergencyPrimary, in: Circle())
            }
            .buttonStyle(.plain)
            TextField("Speak or type...", text: Binding(get: { model.draftText }, set: { model.draftText = $0 }), axis: .vertical)
                .textFieldStyle(.plain)
                .padding(10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .lineLimit(1...4)
                .onSubmit { sendIfPossible() }
                .focused($isComposerFocused)
        }
        .padding(12)
        .background(.ultraThinMaterial.opacity(0.5))
    }

    private func sendIfPossible() {
        let t = model.draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        model.sendUserMessage(t)
        model.draftText = ""
    }
}

private struct DispatchMessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .user { Spacer(minLength: 24) }
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                if let actionTitle = message.actionRequiredTitle {
                    Text(actionTitle)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.emergencyPrimary)
                }
                Text(message.text)
                    .font(.subheadline)
                    .foregroundStyle(message.role == .user ? .white : .primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(bubbleBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(alignment: .leading) {
                        if message.actionRequiredTitle != nil {
                            Rectangle()
                                .fill(Color.emergencyPrimary)
                                .frame(width: 3)
                        }
                    }
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if message.role != .user { Spacer(minLength: 24) }
        }
    }

    @ViewBuilder
    private var bubbleBackground: some ShapeStyle {
        switch message.role {
        case .user:
            Color.emergencySecondary
        case .assistant, .system:
            AnyShapeStyle(.ultraThinMaterial)
        }
    }
}

#Preview {
    DispatchWindowView()
        .environment(CrisisCopilotModel())
        .frame(width: 360, height: 500)
}
