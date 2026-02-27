// ProUpgradeView.swift
// Nexus — Jamf EA Dependency Analyzer
// Copyright © 2025 Murat Kolar. Licensed under GNU GPL v3.
// https://github.com/MUMO97/nexus

import SwiftUI

// MARK: - Pro Upgrade Sheet
struct ProUpgradeView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var license = LicenseManager.shared

    @State private var showActivation = false
    @State private var licenseKey     = ""
    @State private var isActivating   = false
    @State private var activationError: String?
    @State private var showUnlock     = false

    var body: some View {
        VStack(spacing: 0) {

            // Header
            VStack(spacing: 12) {
                ZStack(alignment: .bottomTrailing) {
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .neonGlow(color: AppTheme.accentBlue, radius: 16)
                    Text("PRO")
                        .font(.system(size: 8, weight: .black))
                        .foregroundColor(AppTheme.background)
                        .padding(.horizontal, 4).padding(.vertical, 2)
                        .background(AppTheme.proGold, in: Capsule())
                        .offset(x: 4, y: 4)
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

                if showActivation {
                    // License key entry
                    VStack(spacing: 10) {
                        TextField("XXXX-XXXX-XXXX-XXXX", text: $licenseKey)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(AppTheme.background, in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border, lineWidth: 1))
                            .autocorrectionDisabled()

                        if let err = activationError {
                            Text(err)
                                .font(.system(size: 11))
                                .foregroundColor(AppTheme.dangerRed)
                                .multilineTextAlignment(.center)
                        }

                        Button {
                            isActivating   = true
                            activationError = nil
                            Task {
                                do {
                                    try await LicenseManager.shared.activate(licenseKey: licenseKey)
                                    showUnlock = true
                                    dismiss()
                                } catch {
                                    activationError = error.localizedDescription
                                }
                                isActivating = false
                            }
                        } label: {
                            HStack(spacing: 8) {
                                if isActivating { ProgressView().scaleEffect(0.7) }
                                Text(isActivating ? "Verifying..." : "Activate License")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(AppTheme.proGold)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                        .disabled(isActivating || licenseKey.isEmpty)
                    }
                } else {
                    Button {
                        NSWorkspace.shared.open(URL(string: "https://celeast.gumroad.com/l/nexus")!)
                    } label: {
                        Text("Get Nexus Pro — $4.99/mo")
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
                }

                HStack(spacing: 16) {
                    Button(showActivation ? "Back" : "I have a license key") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showActivation.toggle()
                            activationError = nil
                        }
                    }
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.accentBlue)
                    .buttonStyle(.plain)

                    Spacer()

                    Button("Maybe Later") { dismiss() }
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.mutedText)
                        .buttonStyle(.plain)
                }
            }
            .padding(24)
            .background(AppTheme.surface)
        }
        .frame(width: 400)
        .background(AppTheme.background)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showUnlock) {
            ProUnlockView()
        }
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
