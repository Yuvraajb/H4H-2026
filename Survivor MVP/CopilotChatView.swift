//
//  CopilotChatView.swift
//  Survivor MVP
//
//  Crisis Copilot — ChatGPT-style chat window (messages + composer).
//

import SwiftUI

struct CopilotChatView: View {
    @Environment(CrisisCopilotModel.self) private var model
    @FocusState private var isComposerFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            messageList
            composerBar
        }
        .modifier(PanelBackgroundModifier())
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(model.messages) { msg in
                        MessageBubble(message: msg)
                            .id(msg.id)
                    }
                }
                .padding()
            }
            .onChange(of: model.messages.count) { _, _ in
                if let last = model.messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var composerBar: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField("Type a message…", text: Binding(get: { model.draftText }, set: { model.draftText = $0 }), axis: .vertical)
                .textFieldStyle(.plain)
                .padding(12)
                .lineLimit(1...6)
                .onSubmit { sendIfPossible() }
                .focused($isComposerFocused)

            Button(action: sendIfPossible) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .disabled(model.draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
        .background(.ultraThinMaterial.opacity(0.6), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding()
    }

    private func sendIfPossible() {
        let text = model.draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        model.sendUserMessage(text)
        model.draftText = ""
    }
}

private struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .user { Spacer(minLength: 40) }
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .font(.body)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(bubbleBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if message.role != .user { Spacer(minLength: 40) }
        }
    }

    private var bubbleBackground: some ShapeStyle {
        switch message.role {
        case .user:
            return AnyShapeStyle(Color.accentColor.opacity(0.25))
        case .assistant, .system:
            return AnyShapeStyle(.ultraThinMaterial)
        }
    }
}

#Preview {
    CopilotChatView()
        .environment(CrisisCopilotModel())
        .frame(width: 500, height: 400)
}
