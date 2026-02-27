// EAListView.swift
// Nexus — Jamf EA Dependency Analyzer
// Copyright © 2025 Murat Kolar. Licensed under GNU GPL v3.
// https://github.com/MUMO97/nexus

import SwiftUI

struct EAListView: View {
    @EnvironmentObject var appState: AppState
    @State private var showDeleteConfirm      = false
    @State private var showExportBeforeDelete = false

    private var inUseSelectedCount: Int {
        appState.selectedEAs.filter { $0.status == .used }.count
    }

    var body: some View {
        VStack(spacing: 0) {

            // MARK: Search + Select Safe + Export toolbar
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(AppTheme.mutedText)
                        .font(.system(size: 13))
                    TextField("Search extension attributes...", text: $appState.searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.border, lineWidth: 1))

                Spacer()

                // Select all Safe to Delete in current view
                Button {
                    appState.selectAllSafe()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.circle")
                        Text("Select Safe")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppTheme.safeGreen)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(AppTheme.safeGreen.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.safeGreen.opacity(0.25), lineWidth: 1))
                }
                .buttonStyle(.plain)

                ExportMenuButton()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AppTheme.background)

            Divider().overlay(AppTheme.border)

            // MARK: Data type + scope filter chips
            let hasMobile = appState.extensionAttributes.contains { $0.scope == .mobile }
            if appState.availableDataTypes.count > 1 || hasMobile {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        DataTypeChip(label: "All", isActive: appState.filterDataType == nil && appState.filterScope == nil && !appState.filterDisabledOnly) {
                            appState.filterDataType    = nil
                            appState.filterScope       = nil
                            appState.filterDisabledOnly = false
                        }
                        if hasMobile {
                            DataTypeChip(label: "Computer", isActive: appState.filterScope == .computer) {
                                appState.filterScope = appState.filterScope == .computer ? nil : .computer
                            }
                            DataTypeChip(label: "Mobile", isActive: appState.filterScope == .mobile) {
                                appState.filterScope = appState.filterScope == .mobile ? nil : .mobile
                            }
                        }
                        DataTypeChip(label: "Disabled", isActive: appState.filterDisabledOnly) {
                            appState.filterDisabledOnly.toggle()
                        }
                        if appState.availableDataTypes.count > 1 {
                            ForEach(appState.availableDataTypes, id: \.self) { type in
                                DataTypeChip(label: type, isActive: appState.filterDataType == type) {
                                    appState.filterDataType = appState.filterDataType == type ? nil : type
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .background(AppTheme.background)
                Divider().overlay(AppTheme.border)
            }

            // MARK: Action bar — visible only when EAs are checked
            if !appState.selectedEAIDs.isEmpty {
                HStack(spacing: 12) {
                    Text("\(appState.selectedEAIDs.count) selected")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppTheme.mutedText)

                    if inUseSelectedCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 10))
                            Text("\(inUseSelectedCount) In Use")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(AppTheme.warningOrange)
                    }

                    Spacer()

                    Menu {
                        Button { appState.exportCSV(eas: appState.selectedEAs) }
                            label: { Label("Export CSV",         systemImage: "tablecells") }
                        Button { appState.exportJSON(eas: appState.selectedEAs) }
                            label: { Label("Export JSON",        systemImage: "curlybraces") }
                        Button { appState.exportHTMLReport(eas: appState.selectedEAs) }
                            label: { Label("Export HTML Report", systemImage: "doc.richtext") }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Export Selected")
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppTheme.accentBlue)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(AppTheme.accentBlue.opacity(0.1), in: RoundedRectangle(cornerRadius: 7))
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(AppTheme.accentBlue.opacity(0.3), lineWidth: 1))
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()

                    Button { showExportBeforeDelete = true } label: {
                        Label("Delete Selected", systemImage: "trash")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppTheme.dangerRed)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(AppTheme.dangerRed.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
                            .overlay(RoundedRectangle(cornerRadius: 7).stroke(AppTheme.dangerRed.opacity(0.3), lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    Button { appState.selectedEAIDs = [] } label: {
                        Text("Clear")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.mutedText)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(AppTheme.surfaceElevated)

                Divider().overlay(AppTheme.border)
            }

            // MARK: Column headers + select-all
            HStack(spacing: 0) {
                Button {
                    if appState.allVisibleSelected {
                        appState.filteredEAs.forEach { appState.selectedEAIDs.remove($0.id) }
                    } else {
                        appState.filteredEAs.forEach { appState.selectedEAIDs.insert($0.id) }
                    }
                } label: {
                    Image(systemName: appState.allVisibleSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 14))
                        .foregroundColor(appState.allVisibleSelected ? AppTheme.accentBlue : AppTheme.mutedText)
                }
                .buttonStyle(.plain)
                .frame(width: 36)

                SortableColumnHeader(label: "ID",     field: .id,     width: 48,              alignment: .center)
                SortableColumnHeader(label: "NAME",   field: .name,   width: nil,             alignment: .leading)
                SortableColumnHeader(label: "TYPE",   field: nil,     width: 70,              alignment: .center)
                SortableColumnHeader(label: "STATUS", field: .status, width: 130,             alignment: .center)
                SortableColumnHeader(label: "DEPS",   field: .deps,   width: 50,              alignment: .center)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(AppTheme.surfaceElevated)

            Divider().overlay(AppTheme.border)

            if appState.filteredEAs.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 32))
                        .foregroundColor(AppTheme.mutedText)
                    Text("No extension attributes found")
                        .foregroundColor(AppTheme.mutedText)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(appState.filteredEAs) { ea in
                            EARow(
                                ea: ea,
                                isSelected: appState.selectedEA?.id == ea.id,
                                isChecked:  appState.selectedEAIDs.contains(ea.id),
                                isNew:      appState.scanDelta?.newIDs.contains(ea.id) ?? false,
                                onToggle: {
                                    if appState.selectedEAIDs.contains(ea.id) {
                                        appState.selectedEAIDs.remove(ea.id)
                                    } else {
                                        appState.selectedEAIDs.insert(ea.id)
                                    }
                                },
                                onSelect: {
                                    withAnimation(.spring(duration: 0.3)) {
                                        appState.selectedEA = ea
                                    }
                                }
                            )
                            if ea.id != appState.filteredEAs.last?.id {
                                Divider().overlay(AppTheme.border).padding(.horizontal, 16)
                            }
                        }
                    }
                }
            }
        }
        .background(AppTheme.background)
        // Keyboard shortcuts — active only when something is selected
        .background {
            if !appState.selectedEAIDs.isEmpty {
                Group {
                    // ⌘Delete → delete confirmation
                    Button("") { showDeleteConfirm = true }
                        .keyboardShortcut(.delete, modifiers: .command)
                    // Escape → clear selection
                    Button("") { appState.selectedEAIDs = [] }
                        .keyboardShortcut(.escape, modifiers: [])
                }
                .opacity(0)
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
            }
        }
        // Step 1 — offer to export a report before deleting (paper trail)
        .alert("Save a Report First?", isPresented: $showExportBeforeDelete) {
            Button("Export HTML Report") {
                appState.exportHTMLReport(eas: appState.selectedEAs)
                showDeleteConfirm = true
            }
            Button("Skip & Delete", role: .destructive) { showDeleteConfirm = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("It's recommended to export a cleanup report before deleting. The report can be saved as a record or attached to a Confluence page.")
        }
        // Step 2 — delete confirmation — warns extra loudly if In Use EAs are selected
        .alert(
            inUseSelectedCount > 0
                ? "⚠️ \(inUseSelectedCount) Selected EA\(inUseSelectedCount == 1 ? "" : "s") Are In Use"
                : "Delete \(appState.selectedEAIDs.count) Extension Attribute\(appState.selectedEAIDs.count == 1 ? "" : "s")?",
            isPresented: $showDeleteConfirm
        ) {
            Button("Delete", role: .destructive) {
                Task { await appState.deleteSelectedEAs() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if inUseSelectedCount > 0 {
                Text("""
                    \(inUseSelectedCount) of the selected EAs are actively referenced in Smart Groups, \
                    Policies, or Config Profiles. Deleting them will break those configurations.

                    This cannot be undone.
                    """)
            } else {
                Text("This permanently removes them from Jamf Pro. This cannot be undone.")
            }
        }
    }
}

// MARK: - Sortable Column Header
struct SortableColumnHeader: View {
    @EnvironmentObject var appState: AppState
    let label: String
    let field: SortField?
    let width: CGFloat?
    let alignment: Alignment

    var isActive: Bool { field != nil && appState.sortField == field! }

    var body: some View {
        Group {
            if let field {
                Button {
                    if appState.sortField == field {
                        appState.sortAscending.toggle()
                    } else {
                        appState.sortField    = field
                        appState.sortAscending = true
                    }
                } label: {
                    HStack(spacing: 3) {
                        Text(label)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(isActive ? .white : AppTheme.mutedText)
                            .textCase(.uppercase)
                        if isActive {
                            Image(systemName: appState.sortAscending ? "chevron.up" : "chevron.down")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(AppTheme.accentBlue)
                        }
                    }
                    .frame(maxWidth: width ?? .infinity, alignment: alignment)
                }
                .buttonStyle(.plain)
            } else {
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(AppTheme.mutedText)
                    .textCase(.uppercase)
                    .frame(maxWidth: width ?? .infinity, alignment: alignment)
            }
        }
        .frame(width: width)
    }
}

// MARK: - EA Row
struct EARow: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var license = LicenseManager.shared
    let ea: ExtensionAttribute
    let isSelected: Bool
    let isChecked: Bool
    let isNew: Bool
    let onToggle: () -> Void
    let onSelect: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 0) {

            Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 14))
                .foregroundColor(isChecked ? AppTheme.accentBlue : AppTheme.mutedText.opacity(0.5))
                .frame(width: 36)
                .contentShape(Rectangle())
                .onTapGesture { onToggle() }

            HStack(spacing: 0) {
                Text("\(ea.id)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(AppTheme.mutedText)
                    .frame(width: 48)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(ea.name)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        if ea.scope == .mobile {
                            Image(systemName: "iphone")
                                .font(.system(size: 9))
                                .foregroundColor(Color(hex: "64D2FF"))
                        }
                        // Pro: External consumer shield
                        if license.isPro && appState.isExternalConsumer(ea) {
                            Image(systemName: "shield.fill")
                                .font(.system(size: 9))
                                .foregroundColor(AppTheme.proGold)
                        }
                        // Pro: NEW badge for EAs added since last scan
                        if license.isPro && isNew {
                            Text("NEW")
                                .font(.system(size: 8, weight: .black))
                                .foregroundColor(.black)
                                .padding(.horizontal, 4).padding(.vertical, 1)
                                .background(AppTheme.safeGreen, in: Capsule())
                        }
                    }
                    if !ea.enabled {
                        Text("Disabled")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.mutedText)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(ea.data_type ?? "-")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.mutedText)
                    .frame(width: 70)

                HStack(spacing: 5) {
                    Image(systemName: ea.status.icon).font(.system(size: 10))
                    Text(ea.status.rawValue).font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(ea.status.color)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(ea.status.color.opacity(0.12), in: Capsule())
                .neonGlow(color: ea.status.color, radius: isSelected ? 6 : 0)
                .frame(width: 130)

                Text(ea.dependencyCount > 0 ? "\(ea.dependencyCount)" : "-")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(ea.dependencyCount > 0 ? AppTheme.dangerRed : AppTheme.mutedText)
                    .frame(width: 50)
            }
            .contentShape(Rectangle())
            .onTapGesture { onSelect() }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            isChecked  ? AppTheme.accentBlue.opacity(0.06) :
            isSelected ? AppTheme.accentBlue.opacity(0.08) :
            isHovering ? Color.white.opacity(0.03) : Color.clear
        )
        .overlay(alignment: .leading) {
            if isSelected {
                Rectangle()
                    .fill(AppTheme.accentBlue)
                    .frame(width: 3)
                    .neonGlow(color: AppTheme.accentBlue, radius: 6)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .onHover { isHovering = $0 }
    }
}

// MARK: - Export Menu
struct ExportMenuButton: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Menu {
            Button { appState.exportCSV()        } label: { Label("Export CSV",         systemImage: "tablecells") }
            Button { appState.exportJSON()       } label: { Label("Export JSON",        systemImage: "curlybraces") }
            Divider()
            Button { appState.exportHTMLReport() } label: { Label("Export HTML Report", systemImage: "doc.richtext") }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "square.and.arrow.up")
                Text("Export")
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 14).padding(.vertical, 7)
            .background(AppTheme.surfaceElevated, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border, lineWidth: 1))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}

extension Text {
    func tableHeader() -> some View {
        self
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(AppTheme.mutedText)
            .textCase(.uppercase)
    }
}

// MARK: - Data Type Filter Chip
struct DataTypeChip: View {
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(isActive ? .white : AppTheme.mutedText)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(isActive ? AppTheme.accentBlue : AppTheme.surface, in: Capsule())
                .overlay(Capsule().stroke(isActive ? AppTheme.accentBlue.opacity(0.6) : AppTheme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
