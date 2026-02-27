// JamfEAAnalyzerApp.swift
// Nexus — Jamf EA Dependency Analyzer
// Copyright © 2025 Murat Kolar. Licensed under GNU GPL v3.
// https://github.com/MUMO97/nexus

import SwiftUI

private final class AboutWindowController: NSWindowController {
    convenience init() {
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "About Nexus"
        window.contentView = NSHostingView(rootView: AboutView())
        window.isReleasedWhenClosed = false
        self.init(window: window)
    }
}

@main
struct JamfEAAnalyzerApp: App {
    @StateObject private var appState = AppState()
    private let aboutController = AboutWindowController()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 780)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Nexus") {
                    aboutController.window?.center()
                    aboutController.showWindow(nil)
                }
            }
            #if DEBUG
            CommandMenu("Debug") {
                Button("Toggle Pro") {
                    LicenseManager.shared.debugTogglePro()
                }
                .keyboardShortcut("p", modifiers: [.command, .option, .shift])
            }
            #endif
            CommandGroup(after: .newItem) {
                Divider()
                Button("Refresh") {
                    guard appState.isConnected, !appState.isLoading else { return }
                    Task { await appState.refresh() }
                }
                .keyboardShortcut("r", modifiers: .command)

                Divider()
                Button("Export CSV") {
                    guard appState.isConnected else { return }
                    appState.exportCSV()
                }
                .keyboardShortcut("e", modifiers: .command)

                Button("Export JSON") {
                    guard appState.isConnected else { return }
                    appState.exportJSON()
                }
                .keyboardShortcut("e", modifiers: [.command, .option])

                Button("Export HTML Report") {
                    guard appState.isConnected else { return }
                    appState.exportHTMLReport()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
            }
        }
    }
}
