// CacheService.swift
// Nexus — Jamf EA Dependency Analyzer
// Copyright © 2025 Murat Kolar. Licensed under GNU GPL v3.
// https://github.com/MUMO97/nexus

import Foundation

// MARK: - Cache Service
// Persists scan results per server profile to UserDefaults so the UI can show
// stale data immediately on the next connect while a fresh scan runs.
struct CacheService {

    private static func cacheKey(for profileID: UUID) -> String { "scanCache_\(profileID.uuidString)" }
    private static func scanDateKey(for profileID: UUID) -> String { "scanDate_\(profileID.uuidString)" }

    static func save(_ eas: [ExtensionAttribute], for profile: ServerProfile) {
        guard let data = try? JSONEncoder().encode(eas) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey(for: profile.id))
        UserDefaults.standard.set(Date(), forKey: scanDateKey(for: profile.id))
    }

    static func load(for profile: ServerProfile) -> ([ExtensionAttribute], Date)? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey(for: profile.id)),
              let eas  = try? JSONDecoder().decode([ExtensionAttribute].self, from: data),
              let date = UserDefaults.standard.object(forKey: scanDateKey(for: profile.id)) as? Date
        else { return nil }
        return (eas, date)
    }

    static func clear(for profile: ServerProfile) {
        UserDefaults.standard.removeObject(forKey: cacheKey(for: profile.id))
        UserDefaults.standard.removeObject(forKey: scanDateKey(for: profile.id))
    }
}
