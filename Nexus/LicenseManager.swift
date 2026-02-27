// LicenseManager.swift
// Nexus — Jamf EA Dependency Analyzer
// Copyright © 2025 Murat Kolar. Licensed under GNU GPL v3.
// https://github.com/MUMO97/nexus

import Foundation
import Combine

// MARK: - License Manager
// Single source of truth for Pro status.
// When Paddle is integrated, call activate(licenseKey:) from the
// Paddle webhook/callback and verify(licenseKey:) on launch.
final class LicenseManager: ObservableObject {
    static let shared = LicenseManager()

    @Published private(set) var isPro:        Bool = false
    @Published private(set) var justUnlocked: Bool = false

    private let licenseKey = "nexus.license.key"
    private let proKey     = "nexus.pro.active"

    private init() {
        #if DEBUG
        // Override with environment variable for testing:
        // Edit scheme → Run → Arguments → Environment Variables → NEXUS_PRO = 1
        if ProcessInfo.processInfo.environment["NEXUS_PRO"] == "1" {
            isPro = true
        } else {
            isPro = UserDefaults.standard.bool(forKey: proKey)
        }
        #else
        isPro = UserDefaults.standard.bool(forKey: proKey)
        #endif
    }

    // MARK: - Debug only
    #if DEBUG
    func debugTogglePro() {
        if isPro {
            deactivate()
        } else {
            activate(licenseKey: "debug-pro-key")
        }
    }
    #endif

    // MARK: - Free tier limits
    static let freeServerLimit = 1

    var hasReachedServerLimit: Bool {
        // Checked externally against serverProfiles.count
        false // placeholder — gating logic in AppState
    }

    // MARK: - Activate
    // Call this when Paddle confirms a valid purchase/subscription.
    func activate(licenseKey: String) {
        UserDefaults.standard.set(licenseKey, forKey: self.licenseKey)
        UserDefaults.standard.set(true, forKey: proKey)
        isPro         = true
        justUnlocked  = true
    }

    func clearJustUnlocked() {
        justUnlocked = false
    }

    // MARK: - Deactivate
    // Call this on subscription cancellation/expiry webhook from Paddle.
    func deactivate() {
        UserDefaults.standard.removeObject(forKey: licenseKey)
        UserDefaults.standard.set(false, forKey: proKey)
        isPro = false
    }

    // MARK: - Stored license key (for Paddle verification on launch)
    var storedLicenseKey: String? {
        UserDefaults.standard.string(forKey: licenseKey)
    }
}
