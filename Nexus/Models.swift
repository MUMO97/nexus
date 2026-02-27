// Models.swift
// Nexus — Jamf EA Dependency Analyzer
// Copyright © 2025 Murat Kolar. Licensed under GNU GPL v3.
// https://github.com/MUMO97/nexus

import SwiftUI
import Foundation

// MARK: - Token Response
struct JamfTokenResponse: Codable {
    let access_token: String
    let expires_in: Int
    let token_type: String
}

// MARK: - Server Profile
struct ServerProfile: Identifiable, Codable, Equatable, Hashable {
    var id: UUID = UUID()
    var name: String
    var url: String
    var clientID: String
}

// MARK: - EA Status
enum EAStatus: String, Codable, CaseIterable {
    case safe     = "Safe to Delete"
    case used     = "In Use"
    case orphaned = "Orphaned"
    case unknown  = "Scanning..."

    var color: Color {
        switch self {
        case .safe:     return AppTheme.safeGreen
        case .used:     return AppTheme.dangerRed
        case .orphaned: return AppTheme.warningOrange
        case .unknown:  return AppTheme.mutedText
        }
    }

    var icon: String {
        switch self {
        case .safe:     return "checkmark.circle.fill"
        case .used:     return "exclamationmark.triangle.fill"
        case .orphaned: return "moon.zzz.fill"
        case .unknown:  return "questionmark.circle.fill"
        }
    }

    // Sort priority: In Use first (most dangerous), then Orphaned, then Safe
    var sortPriority: Int {
        switch self {
        case .used:     return 0
        case .orphaned: return 1
        case .safe:     return 2
        case .unknown:  return 3
        }
    }
}

// MARK: - EA Scope
enum EAScope: String, Codable, CaseIterable {
    case computer = "Computer"
    case mobile   = "Mobile Device"

    var icon: String {
        switch self {
        case .computer: return "desktopcomputer"
        case .mobile:   return "iphone"
        }
    }
}

// MARK: - Sort Field
enum SortField {
    case id, name, status, deps
}

// MARK: - Delete Log Entry
struct DeleteLogEntry: Identifiable {
    let id      = UUID()
    let eaName:  String
    let eaID:    Int
    let deletedAt: Date

    var timeAgo: String {
        let secs = Int(-deletedAt.timeIntervalSinceNow)
        if secs < 60  { return "\(secs)s ago" }
        if secs < 3600 { return "\(secs / 60)m ago" }
        return "\(secs / 3600)h ago"
    }
}

// MARK: - Dependency Type
enum DependencyType: String, Codable {
    case smartGroup            = "Smart Group"
    case advancedSearch        = "Advanced Search"
    case advancedSearchDisplay = "Advanced Search (Display)"
    case policy                = "Policy"
    case configProfile         = "Config Profile"
    case restrictedSoftware    = "Restricted Software"
    case patchPolicy           = "Patch Policy"
    case mobileSmartGroup      = "Mobile Smart Group"
    case mobileAdvancedSearch  = "Mobile Advanced Search"
    case mobileConfigProfile   = "Mobile Config Profile"

    var icon: String {
        switch self {
        case .smartGroup:            return "person.3.fill"
        case .advancedSearch:        return "magnifyingglass.circle.fill"
        case .advancedSearchDisplay: return "tablecells.fill"
        case .policy:                return "gearshape.fill"
        case .configProfile:         return "lock.shield.fill"
        case .restrictedSoftware:    return "xmark.shield.fill"
        case .patchPolicy:           return "bandage.fill"
        case .mobileSmartGroup:      return "person.3.sequence.fill"
        case .mobileAdvancedSearch:  return "iphone.and.arrow.forward"
        case .mobileConfigProfile:   return "iphone.badge.play"
        }
    }

    var color: Color {
        switch self {
        case .smartGroup:            return AppTheme.accentBlue
        case .advancedSearch:        return AppTheme.accentPurple
        case .advancedSearchDisplay: return AppTheme.warningOrange
        case .policy:                return AppTheme.safeGreen
        case .configProfile:         return AppTheme.dangerRed
        case .restrictedSoftware:    return Color(hex: "FF6BCB")
        case .patchPolicy:           return Color(hex: "5AC8FA")
        case .mobileSmartGroup:      return Color(hex: "64D2FF")
        case .mobileAdvancedSearch:  return Color(hex: "BF5AF2")
        case .mobileConfigProfile:   return Color(hex: "FF9F0A")
        }
    }
}

// MARK: - Dependency Item
struct DependencyItem: Identifiable, Codable {
    let id: UUID
    let sourceID: Int
    let name: String
    let type: DependencyType

    nonisolated init(sourceID: Int, name: String, type: DependencyType) {
        self.id       = UUID()
        self.sourceID = sourceID
        self.name     = name
        self.type     = type
    }
}

// MARK: - Auto-Scan Interval (Pro)
enum AutoScanInterval: Int, CaseIterable, Codable {
    case off      = 0
    case min30    = 30
    case hour1    = 60
    case hour2    = 120
    case daily    = 1440

    var label: String {
        switch self {
        case .off:   return "Off"
        case .min30: return "Every 30 min"
        case .hour1: return "Every hour"
        case .hour2: return "Every 2 hours"
        case .daily: return "Daily"
        }
    }

    var seconds: TimeInterval { TimeInterval(rawValue) * 60 }
}

// MARK: - Scan Snapshot (Pro — history/delta)
struct ScanSnapshot: Codable {
    let date:     Date
    let eaIDs:    [Int]
    let statuses: [Int: String]   // eaID → EAStatus.rawValue

    init(eas: [ExtensionAttribute]) {
        self.date     = Date()
        self.eaIDs    = eas.map(\.id)
        self.statuses = Dictionary(uniqueKeysWithValues: eas.map { ($0.id, $0.status.rawValue) })
    }
}

// MARK: - Scan Delta (Pro)
struct ScanDelta {
    let newIDs:       Set<Int>
    let removedCount: Int
    let changedIDs:   Set<Int>

    var hasChanges: Bool { !newIDs.isEmpty || removedCount > 0 || !changedIDs.isEmpty }
}

// MARK: - Extension Attribute
struct ExtensionAttribute: Identifiable, Codable {
    let id: Int
    let name: String
    let data_type: String?
    let enabled: Bool
    var status: EAStatus = .unknown
    var dependencies: [DependencyItem] = []
    var scope: EAScope = .computer

    var dependencyCount: Int { dependencies.count }

    enum CodingKeys: String, CodingKey {
        case id, name, data_type, enabled, status, dependencies, scope
    }
}
