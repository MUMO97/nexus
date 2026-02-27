// AboutView.swift
// Nexus — Jamf EA Dependency Analyzer
// Copyright © 2025 Murat Kolar. Licensed under GNU GPL v3.
// https://github.com/MUMO97/nexus

import SwiftUI

struct AboutView: View {
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .neonGlow(color: AppTheme.accentBlue, radius: 16)

                Text("Nexus")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("Jamf EA Dependency Analyzer")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.mutedText)

                Text("Version \(appVersion)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(AppTheme.mutedText.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .background(AppTheme.surface)

            Divider().overlay(AppTheme.border)

            // Info rows
            VStack(spacing: 0) {
                AboutRow(label: "Developer", value: "Murat Kolar")
                Divider().overlay(AppTheme.border).padding(.horizontal, 20)
                AboutRow(label: "License", value: "GNU General Public License v3")
                Divider().overlay(AppTheme.border).padding(.horizontal, 20)
                AboutRow(label: "Platform", value: "macOS 14.0+")
                Divider().overlay(AppTheme.border).padding(.horizontal, 20)

                // Links
                HStack {
                    Text("Source Code")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.mutedText)
                    Spacer()
                    Link("github.com/MUMO97/nexus",
                         destination: URL(string: "https://github.com/MUMO97/nexus")!)
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.accentBlue)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)

                Divider().overlay(AppTheme.border).padding(.horizontal, 20)

                HStack {
                    Text("Support")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.mutedText)
                    Spacer()
                    Link("#nexus-dependency-analyzer",
                         destination: URL(string: "https://macadmins.slack.com/channels/nexus-dependency-analyzer")!)
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.accentBlue)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
            .background(AppTheme.background)

            Divider().overlay(AppTheme.border)

            // Copyright + license notice
            VStack(spacing: 6) {
                Text("Copyright © 2025 Murat Kolar. All rights reserved.")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.mutedText.opacity(0.7))
                    .multilineTextAlignment(.center)

                Text("This software is protected by copyright law and distributed under the\nGNU General Public License v3. Unauthorised reproduction, distribution,\nor commercial use without permission is strictly prohibited.")
                    .font(.system(size: 10))
                    .foregroundColor(AppTheme.mutedText.opacity(0.45))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(AppTheme.surface)
        }
        .frame(width: 380)
        .background(AppTheme.background)
        .preferredColorScheme(.dark)
    }
}

private struct AboutRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(AppTheme.mutedText)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }
}
