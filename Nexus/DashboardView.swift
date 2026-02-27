// DashboardView.swift
// Nexus — Jamf EA Dependency Analyzer
// Copyright © 2025 Murat Kolar. Licensed under GNU GPL v3.
// https://github.com/MUMO97/nexus

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 280)
        } content: {
            EAListView()
                .navigationSplitViewColumnWidth(min: 380, ideal: 460, max: 600)
        } detail: {
            DetailView()
        }
        .background(AppTheme.background)
        .toolbarBackground(AppTheme.surface, for: .windowToolbar)
        // Permission error alert — shown whenever a delete is blocked by Jamf API role
        .alert("Insufficient Permissions", isPresented: Binding(
            get: { appState.permissionError != nil },
            set: { if !$0 { appState.permissionError = nil } }
        )) {
            Button("Open Jamf API Settings") {
                if let url = URL(string: "\(appState.connectedURL)/apiRoles.html") {
                    NSWorkspace.shared.open(url)
                }
                appState.permissionError = nil
            }
            Button("OK", role: .cancel) { appState.permissionError = nil }
        } message: {
            Text(appState.permissionError ?? "")
        }
    }
}
