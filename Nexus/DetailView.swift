// DetailView.swift
// Nexus — Jamf EA Dependency Analyzer
// Copyright © 2025 Murat Kolar. Licensed under GNU GPL v3.
// https://github.com/MUMO97/nexus

import SwiftUI

struct DetailView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if let ea = appState.selectedEA {
                EADetailPanel(ea: ea)
            } else {
                EmptyDetailView()
            }
        }
        .background(AppTheme.background)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EmptyDetailView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.left.circle")
                .font(.system(size: 40))
                .foregroundColor(AppTheme.mutedText)
            Text("Select an EA to inspect")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(AppTheme.mutedText)
        }
    }
}

struct EADetailPanel: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var license = LicenseManager.shared
    let ea: ExtensionAttribute

    @State private var script: String? = nil
    @State private var scriptLoading = false

    // Script editing (Pro)
    @State private var isEditingScript = false
    @State private var editedScript    = ""
    @State private var isSavingScript  = false
    @State private var saveError:       String? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(ea.status.color.opacity(0.15))
                                .frame(width: 44, height: 44)
                                .neonGlow(color: ea.status.color, radius: 12)
                            Image(systemName: ea.status.icon)
                                .font(.system(size: 18))
                                .foregroundColor(ea.status.color)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(ea.name)
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(.white)
                                    .lineLimit(2)
                                Button {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(ea.name, forType: .string)
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 11))
                                        .foregroundColor(AppTheme.mutedText)
                                }
                                .buttonStyle(.plain)
                                .help("Copy name")
                            }
                            HStack(spacing: 6) {
                                Text("ID: \(ea.id)")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(AppTheme.mutedText)
                                Button {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString("\(ea.id)", forType: .string)
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 11))
                                        .foregroundColor(AppTheme.mutedText)
                                }
                                .buttonStyle(.plain)
                                .help("Copy ID")
                            }
                        }
                    }

                    HStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: ea.status.icon).font(.system(size: 12))
                            Text(ea.status.rawValue).font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(ea.status.color)
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(ea.status.color.opacity(0.12), in: Capsule())
                        .neonGlow(color: ea.status.color, radius: 8)

                        // External consumer badge (Pro)
                        if license.isPro && appState.isExternalConsumer(ea) {
                            HStack(spacing: 5) {
                                Image(systemName: "shield.fill").font(.system(size: 10))
                                Text("External").font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundColor(AppTheme.proGold)
                            .padding(.horizontal, 9).padding(.vertical, 5)
                            .background(AppTheme.proGold.opacity(0.12), in: Capsule())
                            .overlay(Capsule().stroke(AppTheme.proGold.opacity(0.3), lineWidth: 1))
                        }

                        Spacer()

                        Button {
                            let urlString = "\(appState.connectedURL)/computerExtensionAttributes.html?id=\(ea.id)"
                            if let url = URL(string: urlString) {
                                NSWorkspace.shared.open(url)
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.up.right.square")
                                    .font(.system(size: 11))
                                Text("Open in Jamf")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundColor(AppTheme.accentBlue)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(AppTheme.accentBlue.opacity(0.1), in: Capsule())
                            .overlay(Capsule().stroke(AppTheme.accentBlue.opacity(0.3), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
                .glassCard(cornerRadius: 16)

                // Properties
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader("Properties")
                    DetailPropertyRow(label: "Data Type", value: ea.data_type ?? "Unknown")
                    DetailPropertyRow(label: "Enabled",   value: ea.enabled ? "Yes" : "No")

                    if ea.dependencies.isEmpty {
                        DetailPropertyRow(label: "Dependencies", value: "0")
                    } else {
                        let grouped = Dictionary(grouping: ea.dependencies) { $0.type }
                        DetailPropertyRow(label: "Dependencies", value: "\(ea.dependencyCount) total")
                        ForEach(Array(grouped.keys).sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { type in
                            HStack {
                                HStack(spacing: 5) {
                                    Image(systemName: type.icon)
                                        .font(.system(size: 10))
                                        .foregroundColor(type.color)
                                    Text(type.rawValue)
                                        .font(.system(size: 12))
                                        .foregroundColor(AppTheme.mutedText)
                                }
                                Spacer()
                                Text("\(grouped[type]?.count ?? 0)")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(type.color)
                            }
                            .padding(.leading, 8)
                        }
                    }

                    // Pro — External Consumer toggle
                    if license.isPro {
                        Divider().overlay(AppTheme.border)
                        HStack(spacing: 10) {
                            Image(systemName: "shield.lefthalf.filled")
                                .font(.system(size: 12))
                                .foregroundColor(appState.isExternalConsumer(ea) ? AppTheme.proGold : AppTheme.mutedText)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("External Consumer")
                                    .font(.system(size: 13))
                                    .foregroundColor(appState.isExternalConsumer(ea) ? .white : AppTheme.mutedText)
                                Text("Flag if used by SIEM, Cortex, or other external tools")
                                    .font(.system(size: 10))
                                    .foregroundColor(AppTheme.mutedText)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { appState.isExternalConsumer(ea) },
                                set: { _ in appState.toggleExternalConsumer(ea) }
                            ))
                            .toggleStyle(.switch)
                            .scaleEffect(0.7)
                            .frame(width: 36)
                            .tint(AppTheme.proGold)
                        }
                    }
                }
                .padding(20)
                .glassCard(cornerRadius: 16)

                // Mobile EA — no dependencies info hint
                if ea.scope == .mobile && ea.dependencies.isEmpty && ea.status != .unknown {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "64D2FF"))
                        Text("Mobile config profiles and smart groups rarely reference EAs in criteria. Zero dependencies is expected for most mobile EAs.")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.mutedText)
                    }
                    .padding(14)
                    .background(Color(hex: "64D2FF").opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "64D2FF").opacity(0.2), lineWidth: 1))
                }

                // Node Graph
                if !ea.dependencies.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader("Dependency Graph")
                        NodeGraphView(ea: ea)
                            .frame(height: 260)
                    }
                    .padding(20)
                    .glassCard(cornerRadius: 16)
                }

                // Dependency List
                if !ea.dependencies.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader("Used In (\(ea.dependencyCount))")
                        ForEach(ea.dependencies) { dep in
                            DependencyRow(dep: dep)
                        }
                    }
                    .padding(20)
                    .glassCard(cornerRadius: 16)
                }

                // Script section
                if scriptLoading {
                    HStack(spacing: 8) {
                        ProgressView().scaleEffect(0.7)
                        Text("Loading script...").font(.system(size: 12)).foregroundColor(AppTheme.mutedText)
                    }
                    .padding(20)
                    .glassCard(cornerRadius: 16)
                } else if let src = script {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            SectionHeader("Script")
                            Spacer()
                            // Pro: Edit button
                            if license.isPro && !isEditingScript {
                                Button {
                                    editedScript    = src
                                    saveError       = nil
                                    isEditingScript = true
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "pencil").font(.system(size: 10))
                                        Text("Edit").font(.system(size: 11))
                                    }
                                    .foregroundColor(AppTheme.proGold)
                                }
                                .buttonStyle(.plain)
                            }
                            if !isEditingScript {
                                Button {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(src, forType: .string)
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "doc.on.doc").font(.system(size: 10))
                                        Text("Copy").font(.system(size: 11))
                                    }
                                    .foregroundColor(AppTheme.accentBlue)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if isEditingScript {
                            // Editable script view
                            TextEditor(text: $editedScript)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(Color(hex: "98C379"))
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 180, maxHeight: 340)
                                .padding(12)
                                .background(Color(hex: "0D1117"), in: RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(AppTheme.proGold.opacity(0.4), lineWidth: 1)
                                )

                            if let err = saveError {
                                Text(err)
                                    .font(.system(size: 11))
                                    .foregroundColor(AppTheme.dangerRed)
                            }

                            HStack(spacing: 10) {
                                Button("Cancel") {
                                    isEditingScript = false
                                    saveError       = nil
                                }
                                .foregroundColor(AppTheme.mutedText)
                                .font(.system(size: 12))
                                .buttonStyle(.plain)

                                Spacer()

                                Button {
                                    isSavingScript = true
                                    saveError      = nil
                                    Task {
                                        do {
                                            try await appState.saveEAScript(ea: ea, newScript: editedScript)
                                            script          = editedScript
                                            isEditingScript = false
                                        } catch {
                                            saveError = "Save failed: \(error.localizedDescription)"
                                        }
                                        isSavingScript = false
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        if isSavingScript { ProgressView().scaleEffect(0.6) }
                                        Text(isSavingScript ? "Saving..." : "Save to Jamf")
                                            .font(.system(size: 12, weight: .semibold))
                                    }
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 14).padding(.vertical, 6)
                                    .background(AppTheme.proGold, in: RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                                .disabled(isSavingScript)
                            }
                        } else {
                            ScrollView(.vertical, showsIndicators: true) {
                                Text(src)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(Color(hex: "98C379"))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                            }
                            .frame(maxHeight: 240)
                            .padding(12)
                            .background(Color(hex: "0D1117"), in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.border, lineWidth: 1))
                        }
                    }
                    .padding(20)
                    .glassCard(cornerRadius: 16)
                }

                Spacer(minLength: 20)
            }
            .padding(16)
        }
        .task(id: ea.id) {
            script          = nil
            scriptLoading   = true
            isEditingScript = false
            saveError       = nil
            script = try? await appState.fetchEAScript(ea: ea)
            scriptLoading = false
        }
    }
}

struct SectionHeader: View {
    let title: String
    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(AppTheme.mutedText)
            .textCase(.uppercase)
    }
}

struct DetailPropertyRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label).font(.system(size: 13)).foregroundColor(AppTheme.mutedText)
            Spacer()
            Text(value).font(.system(size: 13, weight: .medium)).foregroundColor(.white)
        }
    }
}

struct DependencyRow: View {
    let dep: DependencyItem

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(dep.type.color.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: dep.type.icon)
                    .font(.system(size: 13))
                    .foregroundColor(dep.type.color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(dep.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(dep.type.rawValue)
                    .font(.system(size: 11))
                    .foregroundColor(dep.type.color)
            }
            Spacer()
        }
        .padding(10)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(dep.type.color.opacity(0.2), lineWidth: 1))
    }
}
