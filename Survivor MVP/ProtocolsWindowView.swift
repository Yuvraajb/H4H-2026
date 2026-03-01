//
//  ProtocolsWindowView.swift
//  Survivor MVP
//
//  First Responder dashboard — Protocols panel: CPR, Choking, Bleeding, Shock.
//

import SwiftUI

struct ProtocolsWindowView: View {
    @Environment(CrisisCopilotModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PROTOCOLS")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(EmergencyProtocol.allCases, id: \.self) { proto in
                    protocolButton(proto)
                }
            }
        }
        .padding(16)
        .frame(minWidth: 280, minHeight: 260)
        .modifier(PanelBackgroundModifier())
    }

    private func protocolButton(_ proto: EmergencyProtocol) -> some View {
        let isSelected = model.selectedProtocol == proto
        return Button {
            model.selectedProtocol = proto
        } label: {
            VStack(spacing: 8) {
                Image(systemName: iconName(for: proto))
                    .font(.title)
                    .foregroundStyle(iconColor(for: proto))
                Text(proto.rawValue)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(isSelected ? Color.emergencyPrimary : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                isSelected ? Color.emergencyPrimary.opacity(0.2) : Color.primary.opacity(0.06),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Color.emergencyPrimary.opacity(0.5) : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private func iconName(for proto: EmergencyProtocol) -> String {
        switch proto {
        case .cpr: return "cross.fill"
        case .choking: return "figure.stand"
        case .bleeding: return "drop.fill"
        case .shock: return "bolt.fill"
        }
    }

    private func iconColor(for proto: EmergencyProtocol) -> Color {
        switch proto {
        case .cpr: return Color.emergencyPrimary
        case .choking: return .orange
        case .bleeding: return Color(red: 0.7, green: 0, blue: 0)
        case .shock: return .purple
        }
    }
}

#Preview {
    ProtocolsWindowView()
        .environment(CrisisCopilotModel())
        .frame(width: 300, height: 280)
}
