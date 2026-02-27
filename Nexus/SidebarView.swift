// SidebarView.swift
// Nexus — Jamf EA Dependency Analyzer
// Copyright © 2025 Murat Kolar. Licensed under GNU GPL v3.
// https://github.com/MUMO97/nexus

import SwiftUI
import Combine

struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var license = LicenseManager.shared
    @State private var showDeleteLog = false
    @State private var showUpgrade   = false
    // Tick every 30 s so token countdown updates
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    @State private var tick = false

    var body: some View {
        VStack(spacing: 0) {

            // MARK: Header
            HStack(spacing: 10) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .neonGlow(color: AppTheme.accentBlue, radius: 8)
                Text("Nexus")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()

                // Refresh button
                Button {
                    Task { await appState.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.accentBlue)
                        .padding(6)
                        .background(AppTheme.accentBlue.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
                .help("Re-authenticate and rescan Jamf")
                .disabled(appState.isLoading)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // MARK: Token expiry warning
            if let mins = appState.tokenMinutesRemaining {
                let expired = appState.tokenIsExpired
                let soon    = appState.tokenIsExpiringSoon

                if expired || soon {
                    HStack(spacing: 6) {
                        Image(systemName: expired ? "exclamationmark.octagon.fill" : "clock.badge.exclamationmark.fill")
                            .font(.system(size: 11))
                        Text(expired ? "Token expired — refresh now" : "Token expires in \(mins)m")
                            .font(.system(size: 11, weight: .semibold))
                        Spacer()
                        if !expired {
                            Button("Refresh") { Task { await appState.refresh() } }
                                .font(.system(size: 10, weight: .bold))
                                .buttonStyle(.plain)
                        }
                    }
                    .foregroundColor(expired ? AppTheme.dangerRed : AppTheme.warningOrange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        (expired ? AppTheme.dangerRed : AppTheme.warningOrange).opacity(0.1),
                        in: RoundedRectangle(cornerRadius: 0)
                    )
                }
            }

            Divider().overlay(AppTheme.border)

            // MARK: Partial scan warning
            if let warning = appState.scanWarning {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                    Text(warning)
                        .font(.system(size: 11))
                        .lineLimit(3)
                    Spacer()
                    Button {
                        appState.scanWarning = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .buttonStyle(.plain)
                }
                .foregroundColor(AppTheme.warningOrange)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(AppTheme.warningOrange.opacity(0.08))

                Divider().overlay(AppTheme.border)
            }

            // MARK: Overview stats
            VStack(spacing: 8) {
                Text("Overview")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(AppTheme.mutedText)
                    .textCase(.uppercase)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 14)

                SidebarStatRow(label: "Total EAs",      value: appState.stats.total,    color: AppTheme.accentBlue)
                SidebarStatRow(label: "Safe to Delete", value: appState.stats.safe,     color: AppTheme.safeGreen)
                SidebarStatRow(label: "In Use",         value: appState.stats.used,     color: AppTheme.dangerRed)
                SidebarStatRow(label: "Orphaned",       value: appState.stats.orphaned, color: AppTheme.warningOrange)

                if let scanDate = appState.lastScanDate {
                    let df: DateFormatter = {
                        let f = DateFormatter()
                        f.dateStyle = .none
                        f.timeStyle = .short
                        return f
                    }()
                    HStack {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                            .foregroundColor(AppTheme.mutedText.opacity(0.5))
                        Text("Last scan: \(df.string(from: scanDate))")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.mutedText.opacity(0.5))
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 2)
                }
            }
            .padding(.bottom, 8)

            Divider().overlay(AppTheme.border)

            // MARK: Filter
            VStack(spacing: 4) {
                Text("Filter")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(AppTheme.mutedText)
                    .textCase(.uppercase)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 14)

                FilterRow(label: "All",            status: nil,       icon: "square.grid.2x2.fill")
                FilterRow(label: "Safe to Delete", status: .safe,     icon: "checkmark.circle.fill")
                FilterRow(label: "In Use",         status: .used,     icon: "exclamationmark.triangle.fill")
                FilterRow(label: "Orphaned",       status: .orphaned, icon: "moon.zzz.fill")

                // Disabled Only toggle — separate from status filter
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        appState.filterDisabledOnly.toggle()
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "nosign")
                            .font(.system(size: 12))
                            .foregroundColor(appState.filterDisabledOnly ? AppTheme.accentBlue : AppTheme.mutedText)
                            .frame(width: 16)
                        Text("Disabled Only")
                            .font(.system(size: 13, weight: appState.filterDisabledOnly ? .semibold : .regular))
                            .foregroundColor(appState.filterDisabledOnly ? .white : AppTheme.mutedText)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(appState.filterDisabledOnly ? AppTheme.accentBlue.opacity(0.12) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 8)
                }
                .buttonStyle(.plain)

                // Mobile Device EAs toggle
                HStack(spacing: 10) {
                    Image(systemName: "iphone")
                        .font(.system(size: 12))
                        .foregroundColor(appState.includeMobileEAs ? Color(hex: "64D2FF") : AppTheme.mutedText)
                        .frame(width: 16)
                    Text("Mobile Device EAs")
                        .font(.system(size: 13))
                        .foregroundColor(appState.includeMobileEAs ? .white : AppTheme.mutedText)
                    Spacer()
                    Toggle("", isOn: $appState.includeMobileEAs)
                        .toggleStyle(.switch)
                        .scaleEffect(0.7)
                        .frame(width: 36)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .padding(.horizontal, 8)
                .help("Include mobile device extension attributes in the scan. Takes effect on the next refresh.")
            }
            .padding(.bottom, 8)

            Divider().overlay(AppTheme.border)

            // MARK: Delete Log
            if !appState.deleteLog.isEmpty {
                VStack(spacing: 0) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { showDeleteLog.toggle() }
                    } label: {
                        HStack {
                            Text("Delete Log")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(AppTheme.mutedText)
                                .textCase(.uppercase)
                            Spacer()
                            Text("\(appState.deleteLog.count)")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(AppTheme.dangerRed)
                            Image(systemName: showDeleteLog ? "chevron.up" : "chevron.down")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(AppTheme.mutedText)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                        .padding(.bottom, 8)
                    }
                    .buttonStyle(.plain)

                    if showDeleteLog {
                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(appState.deleteLog) { entry in
                                    HStack(spacing: 8) {
                                        Image(systemName: "trash.fill")
                                            .font(.system(size: 9))
                                            .foregroundColor(AppTheme.dangerRed.opacity(0.7))
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(entry.eaName)
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundColor(.white)
                                                .lineLimit(1)
                                            Text("ID \(entry.eaID) · \(entry.timeAgo)")
                                                .font(.system(size: 10))
                                                .foregroundColor(AppTheme.mutedText)
                                        }
                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 5)

                                    if entry.id != appState.deleteLog.last?.id {
                                        Divider().overlay(AppTheme.border).padding(.horizontal, 16)
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 180)
                    }
                }

                Divider().overlay(AppTheme.border)
            }

            Spacer()

            // MARK: Support links
            VStack(spacing: 6) {
                Link(destination: URL(string: "https://github.com/MUMO97/nexus")!) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .font(.system(size: 10))
                        Text("GitHub")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(AppTheme.mutedText.opacity(0.6))
                }
                .buttonStyle(.plain)

                Link(destination: URL(string: "https://macadmins.slack.com/channels/nexus-dependency-analyzer")!) {
                    HStack(spacing: 6) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 10))
                        Text("#nexus-dependency-analyzer")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(AppTheme.mutedText.opacity(0.6))
                }
                .buttonStyle(.plain)

                Text("Nexus v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0") · by Murat Kolar")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(AppTheme.mutedText.opacity(0.35))
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 8)

            // Pro upgrade banner (free users only)
            if !license.isPro {
                Button { showUpgrade = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.accentBlue)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Upgrade to Nexus Pro")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                            Text("Unlimited servers · Auto-scan · More")
                                .font(.system(size: 10))
                                .foregroundColor(AppTheme.mutedText)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(AppTheme.mutedText)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(AppTheme.accentBlue.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.accentBlue.opacity(0.2), lineWidth: 1))
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
                .buttonStyle(.plain)
            }

            Divider().overlay(AppTheme.border)

            // MARK: Disconnect
            Button {
                appState.disconnect()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "eject.circle.fill")
                        .foregroundColor(AppTheme.dangerRed)
                    Text("Disconnect")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.dangerRed)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
        }
        .background(AppTheme.surface)
        .onReceive(timer) { _ in tick.toggle() }
        .sheet(isPresented: $showUpgrade) { ProUpgradeView() }
    }
}

struct SidebarStatRow: View {
    let label: String
    let value: Int
    let color: Color

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .neonGlow(color: color, radius: 4)
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(AppTheme.mutedText)
            Spacer()
            Text("\(value)")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}

struct FilterRow: View {
    @EnvironmentObject var appState: AppState
    let label: String
    let status: EAStatus?
    let icon: String

    var isSelected: Bool { appState.filterStatus == status }

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                appState.filterStatus = isSelected ? nil : status
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? AppTheme.accentBlue : AppTheme.mutedText)
                    .frame(width: 16)
                Text(label)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : AppTheme.mutedText)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .background(isSelected ? AppTheme.accentBlue.opacity(0.12) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 8)
        }
        .buttonStyle(.plain)
    }
}
