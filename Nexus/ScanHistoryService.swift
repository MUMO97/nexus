// ScanHistoryService.swift
// Nexus — Jamf EA Dependency Analyzer
// Copyright © 2025 Murat Kolar. Licensed under GNU GPL v3.
// https://github.com/MUMO97/nexus

import Foundation

// MARK: - Scan History Service (Pro)
// Persists up to 5 scan snapshots per server profile.
// Used to compute deltas between the current scan and the previous one.
struct ScanHistoryService {
    private static let maxSnapshots = 5

    private static func key(for profile: ServerProfile) -> String {
        "nexus.history.\(profile.id.uuidString)"
    }

    // MARK: Save
    static func save(_ eas: [ExtensionAttribute], for profile: ServerProfile) {
        var snapshots = load(for: profile)
        snapshots.insert(ScanSnapshot(eas: eas), at: 0)
        if snapshots.count > maxSnapshots { snapshots = Array(snapshots.prefix(maxSnapshots)) }
        if let data = try? JSONEncoder().encode(snapshots) {
            UserDefaults.standard.set(data, forKey: key(for: profile))
        }
    }

    // MARK: Load
    static func load(for profile: ServerProfile) -> [ScanSnapshot] {
        guard let data = UserDefaults.standard.data(forKey: key(for: profile)),
              let decoded = try? JSONDecoder().decode([ScanSnapshot].self, from: data)
        else { return [] }
        return decoded
    }

    // MARK: Delta — compare current EAs against the most recent previous snapshot
    static func delta(current: [ExtensionAttribute], for profile: ServerProfile) -> ScanDelta? {
        let snapshots = load(for: profile)
        // Need at least 2 (index 0 = just saved current, index 1 = previous)
        guard snapshots.count >= 2 else { return nil }
        let previous = snapshots[1]

        let currentIDs  = Set(current.map(\.id))
        let previousIDs = Set(previous.eaIDs)

        let newIDs       = currentIDs.subtracting(previousIDs)
        let removedCount = previousIDs.subtracting(currentIDs).count

        // Changed = existed in both but status changed
        let changedIDs = currentIDs.intersection(previousIDs).filter { id in
            guard let prevStatus = previous.statuses[id],
                  let currEA    = current.first(where: { $0.id == id })
            else { return false }
            return currEA.status.rawValue != prevStatus
        }

        let delta = ScanDelta(newIDs: newIDs, removedCount: removedCount, changedIDs: Set(changedIDs))
        return delta.hasChanges ? delta : nil
    }

    // MARK: Clear
    static func clear(for profile: ServerProfile) {
        UserDefaults.standard.removeObject(forKey: key(for: profile))
    }
}
