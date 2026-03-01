//
//  PTTMicButton.swift
//  Survivor MVP
//
//  Push-to-talk mic: press and hold to record, release to send. Optional hands-free (tap to start, tap to stop).
//

import SwiftUI

struct PTTMicButton: View {
    let isListening: Bool
    let handsFreeMode: Bool
    let onPress: () -> Void
    let onRelease: () -> Void
    let onTap: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button {
            if handsFreeMode {
                onTap()
            }
        } label: {
            Image(systemName: isListening ? "waveform" : "mic.fill")
                .font(.title2)
                .symbolEffect(.variableColor.iterative, isActive: isListening)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !handsFreeMode && !isPressed {
                        isPressed = true
                        onPress()
                    }
                }
                .onEnded { _ in
                    if !handsFreeMode && isPressed {
                        isPressed = false
                        onRelease()
                    }
                }
        )
    }
}
