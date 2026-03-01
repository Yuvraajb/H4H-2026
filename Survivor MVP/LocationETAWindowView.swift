//
//  LocationETAWindowView.swift
//  Survivor MVP
//
//  First Responder dashboard — Location & ETA: map, nearest AED, ambulance ETA.
//

import SwiftUI

struct LocationETAWindowView: View {
    @Environment(CrisisCopilotModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            mapSection
            VStack(alignment: .leading, spacing: 14) {
                nearestAEDSection
                ambulanceETASection
            }
            .padding(14)
        }
        .frame(minWidth: 320, minHeight: 320)
        .modifier(PanelBackgroundModifier())
    }

    private var mapSection: some View {
        ZStack(alignment: .center) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemGray5))
                .overlay(
                    Image(systemName: "map.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary.opacity(0.5))
                )
            // You marker
            VStack(spacing: 4) {
                Circle()
                    .fill(Color.emergencySecondary)
                    .frame(width: 14, height: 14)
                    .overlay(Circle().stroke(.white, lineWidth: 2))
                Text("You")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.background, in: Capsule())
            }
            .offset(x: -40, y: -20)
            // AED marker
            VStack(spacing: 4) {
                Image(systemName: "heart.text.square.fill")
                    .font(.title2)
                    .foregroundStyle(Color.emergencyPrimary)
                Text("AED")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.background, in: Capsule())
            }
            .offset(x: 30, y: 15)
        }
        .frame(height: 120)
        .padding(.horizontal, 14)
        .padding(.top, 14)
    }

    private var nearestAEDSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("NEAREST AED")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "heart.text.square.fill")
                    .font(.title3)
                    .foregroundStyle(Color.emergencyPrimary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.locationStub.nearestAEDName)
                        .font(.subheadline)
                        .fontWeight(.bold)
                    Text(model.locationStub.nearestAEDDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(model.locationStub.nearestAEDDistance)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.emergencySecondary)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var ambulanceETASection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("AMBULANCE ETA")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.emergencySecondary)
                        .frame(width: 44, height: 44)
                    Image(systemName: "cross.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(model.locationStub.ambulanceETAMinutes) min")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.emergencySecondary)
                    Text(model.locationStub.ambulanceUnit)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(Color.emergencySecondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

#Preview {
    LocationETAWindowView()
        .environment(CrisisCopilotModel())
        .frame(width: 360, height: 340)
}
