//
//  BannerView.swift
//  Survivor MVP
//
//  Small top banner for permission/error messages (mic, speech, camera, TTS key, network).
//

import SwiftUI

struct BannerView: View {
    let message: String
    let style: BannerStyle

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: style.iconName)
                .font(.caption)
            Text(message)
                .font(.caption)
                .lineLimit(2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(style.backgroundColor.opacity(0.9), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    enum BannerStyle {
        case warning
        case error
        case info

        var iconName: String {
            switch self {
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.circle.fill"
            case .info: return "info.circle.fill"
            }
        }

        var backgroundColor: Color {
            switch self {
            case .warning: return .orange
            case .error: return .red
            case .info: return .blue
            }
        }
    }
}
