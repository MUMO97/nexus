// LicenseManager.swift
// Nexus — Jamf EA Dependency Analyzer
// Copyright © 2025 Murat Kolar. Licensed under GNU GPL v3.
// https://github.com/MUMO97/nexus

import Foundation
import Combine

// MARK: - Gumroad API response
private struct GumroadVerifyResponse: Codable {
    let success: Bool
    let message: String?
    let purchase: GumroadPurchase?
}

private struct GumroadPurchase: Codable {
    let refunded:                  Bool?
    let disputed:                  Bool?
    let dispute_won:               Bool?
    let subscription_cancelled_at: String?
    let subscription_failed_at:    String?
    let subscription_ended_at:     String?
}

// MARK: - License Manager
final class LicenseManager: ObservableObject {
    static let shared = LicenseManager()

    @Published private(set) var isPro:        Bool = false
    @Published private(set) var justUnlocked: Bool = false

    private let keychainKey = "nexus.license.key"
    private let proKey      = "nexus.pro.active"
    private let productID   = "NHdFRF3ja7LP6JZ-hLLqgg=="

    // MARK: Free tier limits
    static let freeServerLimit = 1

    private init() {
        #if DEBUG
        if ProcessInfo.processInfo.environment["NEXUS_PRO"] == "1" {
            isPro = true
            return
        }
        #endif
        isPro = UserDefaults.standard.bool(forKey: proKey)
    }

    // MARK: - Launch verification
    // Call on app launch to re-verify the stored key is still valid.
    func verifyOnLaunch() async {
        guard let key = storedLicenseKey else { return }
        do {
            let valid = try await verifyWithGumroad(key, incrementUses: false)
            await MainActor.run {
                if !valid { deactivate() }
            }
        } catch {
            // Network error — keep existing Pro status, don't revoke offline
        }
    }

    // MARK: - Activate with Gumroad key
    @MainActor
    func activate(licenseKey: String) async throws {
        let trimmed = licenseKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw LicenseError.emptyKey }

        let valid = try await verifyWithGumroad(trimmed, incrementUses: true)
        guard valid else { throw LicenseError.invalid }

        KeychainService.shared.save(trimmed, for: keychainKey)
        UserDefaults.standard.set(true, forKey: proKey)
        isPro        = true
        justUnlocked = true
    }

    func clearJustUnlocked() {
        justUnlocked = false
    }

    // MARK: - Deactivate
    func deactivate() {
        KeychainService.shared.delete(for: keychainKey)
        UserDefaults.standard.set(false, forKey: proKey)
        isPro = false
    }

    // MARK: - Stored key
    var storedLicenseKey: String? {
        KeychainService.shared.load(for: keychainKey)
    }

    // MARK: - Gumroad API call
    private func verifyWithGumroad(_ key: String, incrementUses: Bool) async throws -> Bool {
        guard let url = URL(string: "https://api.gumroad.com/v2/licenses/verify") else {
            throw LicenseError.networkError
        }
        var request        = URLRequest(url: url, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let encodedID  = productID.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? productID
        let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
        let body = "product_id=\(encodedID)&license_key=\(encodedKey)&increment_uses_count=\(incrementUses ? "true" : "false")"
        request.httpBody = body.data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: request)
        let result    = try JSONDecoder().decode(GumroadVerifyResponse.self, from: data)

        guard result.success,
              let purchase = result.purchase
        else { return false }

        // Reject refunded or active dispute
        if purchase.refunded == true { return false }
        if purchase.disputed == true && purchase.dispute_won != true { return false }

        // Reject if subscription fully ended
        if purchase.subscription_ended_at != nil { return false }

        return true
    }

    // MARK: - Debug only
    #if DEBUG
    func debugTogglePro() {
        if isPro {
            deactivate()
        } else {
            UserDefaults.standard.set(true, forKey: proKey)
            isPro        = true
            justUnlocked = true
        }
    }
    #endif
}

// MARK: - License errors
enum LicenseError: LocalizedError {
    case emptyKey
    case invalid
    case networkError

    var errorDescription: String? {
        switch self {
        case .emptyKey:     return "Please enter your license key."
        case .invalid:      return "License key not found or no longer active. Check your Gumroad email."
        case .networkError: return "Could not reach the license server. Check your internet connection."
        }
    }
}
