// ScanEngine.swift
// Nexus — Jamf EA Dependency Analyzer
// Copyright © 2025 Murat Kolar. Licensed under GNU GPL v3.
// https://github.com/MUMO97/nexus

import Foundation

// MARK: - Scan Result
struct ScanResult {
    let eas: [ExtensionAttribute]
    /// Non-nil when dependency scanning only partially completed (e.g. a phase timed out).
    let warning: String?
}

// MARK: - Scan Engine
// Orchestrates fetching EAs and their dependencies.
// All methods are nonisolated — callers must hop to MainActor to update UI.
// Failures in individual dependency phases are silently swallowed (each scanner
// returns [] on error), but a top-level fetchDependencies failure sets warning
// so the user knows results may be incomplete.
struct ScanEngine {

    private let api = JamfAPIService()

    func run(
        url: String,
        token: String,
        includeMobile: Bool,
        onProgress: @escaping (String) async -> Void
    ) async throws -> ScanResult {

        // --- Computer EAs ---
        await onProgress("Fetching Computer Extension Attributes (0/?)...")
        let computerEAs = try await api.fetchEAs(url: url, token: token) { completed, total in
            await onProgress("Fetching Computer EAs (\(completed)/\(total))...")
        }

        // --- Mobile EAs (optional, fails silently) ---
        var mobileEAs: [ExtensionAttribute] = []
        if includeMobile {
            await onProgress("Fetching Mobile Device Extension Attributes...")
            mobileEAs = (try? await api.fetchMobileEAs(url: url, token: token) { completed, total in
                await onProgress("Fetching Mobile EAs (\(completed)/\(total))...")
            }) ?? []
        }

        // --- Computer dependencies ---
        var depMap: [Int: [DependencyItem]] = [:]
        var warning: String? = nil
        do {
            depMap = try await api.fetchDependencies(baseURL: url, token: token, eas: computerEAs) { status in
                await onProgress(status)
            }
        } catch {
            // Return partial results rather than throwing — the cached EA list
            // is still useful even if dependency mapping is incomplete.
            warning = "Dependency scan incomplete — showing EAs without dependency data. \(error.localizedDescription)"
        }

        // --- Mobile dependencies (optional, fails silently) ---
        var mobileDepMap: [Int: [DependencyItem]] = [:]
        if includeMobile && !mobileEAs.isEmpty {
            mobileDepMap = (try? await api.fetchMobileDependencies(
                baseURL: url, token: token, eas: mobileEAs
            ) { status in
                await onProgress(status)
            }) ?? [:]
        }

        // --- Classify status ---
        let allEAs = (computerEAs + mobileEAs).map { ea -> ExtensionAttribute in
            var m    = ea
            let deps = ea.scope == .mobile ? (mobileDepMap[ea.id] ?? []) : (depMap[ea.id] ?? [])
            m.dependencies = deps
            if !ea.enabled && deps.isEmpty { m.status = .orphaned }
            else if deps.isEmpty           { m.status = .safe }
            else                           { m.status = .used }
            return m
        }

        return ScanResult(eas: allEAs, warning: warning)
    }
}
