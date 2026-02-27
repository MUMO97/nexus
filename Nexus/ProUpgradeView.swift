// ProUpgradeView.swift
// Nexus — Jamf EA Dependency Analyzer
// Copyright © 2025 Murat Kolar. Licensed under GNU GPL v3.
// https://github.com/MUMO97/nexus

import SwiftUI

// MARK: - Pro Upgrade Sheet
struct ProUpgradeView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var license = LicenseManager.shared

    var body: some View {
        VStack(spacing: 0) {

            // Header
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppTheme.accentBlue.opacity(0.15))
                        .frame(width: 64, height: 64)
                        .neonGlow(color: AppTheme.accentBlue, radius: 16)
                    Image(systemName: "star.fill")
                        .font(.system(size: 26))
                        .foregroundColor(AppTheme.accentBlue)
                }

                Text("Nexus Pro")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("Unlock the full power of Nexus")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.mutedText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .background(AppTheme.surface)

            Divider().overlay(AppTheme.border)

            // Feature list
            VStack(alignment: .leading, spacing: 0) {
                ProFeatureRow(
                    icon: "server.rack",
                    color: AppTheme.accentBlue,
                    title: "Unlimited Server Profiles",
                    description: "Connect to and switch between multiple Jamf Pro instances"
                )
                Divider().overlay(AppTheme.border).padding(.horizontal, 20)
                ProFeatureRow(
                    icon: "clock.arrow.2.circlepath",
                    color: Color(hex: "30D158"),
                    title: "Scheduled Auto-Scan",
                    description: "Automatically rescan your environment on a schedule"
                )
                Divider().overlay(AppTheme.border).padding(.horizontal, 20)
                ProFeatureRow(
                    icon: "square.and.pencil",
                    color: Color(hex: "FF9F0A"),
                    title: "EA Script Editing",
                    description: "View and edit EA scripts directly inside Nexus"
                )
                Divider().overlay(AppTheme.border).padding(.horizontal, 20)
                ProFeatureRow(
                    icon: "link.badge.plus",
                    color: Color(hex: "BF5AF2"),
                    title: "External Consumer Protection",
                    description: "Flag EAs used by SIEM tools, Cortex, or other integrations as protected"
                )
                Divider().overlay(AppTheme.border).padding(.horizontal, 20)
                ProFeatureRow(
                    icon: "chart.bar.xaxis",
                    color: Color(hex: "5AC8FA"),
                    title: "Scan History & Delta View",
                    description: "Track changes between scans and see what was added or removed"
                )
            }
            .background(AppTheme.background)

            Divider().overlay(AppTheme.border)

            // Pricing + CTA
            VStack(spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("$4.99")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("/ month")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.mutedText)
                }

                Button {
                    // TODO: Open Paddle checkout URL when approved
                    NSWorkspace.shared.open(URL(string: "https://mumo97.github.io/nexus")!)
                    dismiss()
                } label: {
                    Text("Upgrade to Pro")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [AppTheme.accentBlue, AppTheme.accentPurple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .neonGlow(color: AppTheme.accentBlue, radius: 8)
                }
                .buttonStyle(.plain)

                Button("Maybe Later") { dismiss() }
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.mutedText)
                    .buttonStyle(.plain)
            }
            .padding(24)
            .background(AppTheme.surface)
        }
        .frame(width: 400)
        .background(AppTheme.background)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Pro Feature Row
private struct ProFeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.mutedText)
            }
            Spacer()
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(color)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}
