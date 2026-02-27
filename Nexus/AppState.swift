// AppState.swift
// Nexus — Jamf EA Dependency Analyzer
// Copyright © 2025 Murat Kolar. Licensed under GNU GPL v3.
// https://github.com/MUMO97/nexus

import SwiftUI
import Combine

// MARK: - AppState
// Thin coordinator: owns all @Published UI state and delegates heavy work
// to ScanEngine, CacheService and ExportService.
final class AppState: ObservableObject {

    // MARK: Published — UI state
    @Published var serverProfiles: [ServerProfile] = []
    @Published var isConnected     = false
    @Published var isLoading       = false
    @Published var loadingMessage  = ""
    @Published var errorMessage:    String?
    @Published var scanWarning:     String?   // set when dep scan partially failed
    @Published var permissionError: String?
    @Published var extensionAttributes: [ExtensionAttribute] = []
    @Published var selectedEA:      ExtensionAttribute?
    @Published var searchText      = ""
    @Published var filterStatus:    EAStatus? = nil
    @Published var filterScope:     EAScope?  = nil
    @Published var filterDataType:  String?   = nil
    @Published var filterDisabledOnly = false
    @Published var selectedEAIDs:   Set<Int>  = []
    @Published var includeMobileEAs = true
    @Published var sortField:       SortField = .id
    @Published var sortAscending    = true
    @Published var deleteLog:       [DeleteLogEntry] = []
    @Published var tokenExpiresAt:  Date?
    @Published var lastScanDate:    Date?

    // MARK: Private services
    private let api    = JamfAPIService()
    private let engine = ScanEngine()

    // Stored after auth so delete / script-fetch calls can use them
    var connectedURL:   String = ""
    private var connectedToken:   String = ""
    private var connectedProfile: ServerProfile?

    // MARK: Computed — filtered + sorted list
    var filteredEAs: [ExtensionAttribute] {
        var base = extensionAttributes
        if let s = filterStatus    { base = base.filter { $0.status    == s } }
        if let s = filterScope     { base = base.filter { $0.scope     == s } }
        if let t = filterDataType  { base = base.filter { $0.data_type == t } }
        if filterDisabledOnly      { base = base.filter { !$0.enabled } }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            base = base.filter {
                $0.name.lowercased().contains(q) ||
                $0.dependencies.contains { $0.name.lowercased().contains(q) }
            }
        }
        base.sort { a, b in
            let asc: Bool
            switch sortField {
            case .id:     asc = a.id < b.id
            case .name:   asc = a.name.localizedStandardCompare(b.name) == .orderedAscending
            case .status: asc = a.status.sortPriority < b.status.sortPriority
            case .deps:   asc = a.dependencyCount < b.dependencyCount
            }
            return sortAscending ? asc : !asc
        }
        return base
    }

    var stats: (total: Int, safe: Int, used: Int, orphaned: Int) {
        (
            total:    extensionAttributes.count,
            safe:     extensionAttributes.filter { $0.status == .safe     }.count,
            used:     extensionAttributes.filter { $0.status == .used     }.count,
            orphaned: extensionAttributes.filter { $0.status == .orphaned }.count
        )
    }

    var availableDataTypes: [String] {
        Array(Set(extensionAttributes.compactMap { $0.data_type })).sorted()
    }

    var selectedEAs: [ExtensionAttribute] {
        extensionAttributes.filter { selectedEAIDs.contains($0.id) }
    }

    var allVisibleSelected: Bool {
        !filteredEAs.isEmpty && filteredEAs.allSatisfy { selectedEAIDs.contains($0.id) }
    }

    // MARK: Token helpers
    var tokenMinutesRemaining: Int? {
        guard let exp = tokenExpiresAt else { return nil }
        let secs = exp.timeIntervalSinceNow
        return secs > 0 ? Int(secs / 60) : 0
    }

    var tokenIsExpiringSoon: Bool { (tokenMinutesRemaining ?? Int.max) < 5 }
    var tokenIsExpired: Bool      { tokenExpiresAt.map { $0.timeIntervalSinceNow <= 0 } ?? false }

    // MARK: Profile Management
    func addProfile(_ profile: ServerProfile, secret: String) {
        serverProfiles.append(profile)
        KeychainService.shared.save(secret, for: profile.id.uuidString)
        saveProfiles()
    }

    func deleteProfile(_ profile: ServerProfile) {
        KeychainService.shared.delete(for: profile.id.uuidString)
        serverProfiles.removeAll { $0.id == profile.id }
        CacheService.clear(for: profile)
        saveProfiles()
    }

    func updateProfile(_ profile: ServerProfile, secret: String) {
        if let idx = serverProfiles.firstIndex(where: { $0.id == profile.id }) {
            serverProfiles[idx] = profile
            KeychainService.shared.save(secret, for: profile.id.uuidString)
            saveProfiles()
        }
    }

    func loadProfiles() {
        guard let data    = UserDefaults.standard.data(forKey: "serverProfiles"),
              let decoded = try? JSONDecoder().decode([ServerProfile].self, from: data)
        else { return }
        serverProfiles = decoded
    }

    private func saveProfiles() {
        if let data = try? JSONEncoder().encode(serverProfiles) {
            UserDefaults.standard.set(data, forKey: "serverProfiles")
        }
    }

    // MARK: Connect
    @MainActor
    func connect(profile: ServerProfile) async {
        guard let secret = KeychainService.shared.load(for: profile.id.uuidString) else {
            errorMessage = "No client secret found for this profile."
            return
        }
        isLoading     = true
        errorMessage  = nil
        scanWarning   = nil

        // Show cached results immediately while fresh scan runs
        if let (cached, scanDate) = CacheService.load(for: profile) {
            withAnimation(.spring(duration: 0.4)) {
                extensionAttributes = cached
                lastScanDate        = scanDate
                isConnected         = true
            }
            loadingMessage = "Refreshing scan..."
        }

        do {
            loadingMessage = "Authenticating..."
            let token = try await api.authenticate(url: profile.url, clientID: profile.clientID, clientSecret: secret)
            connectedURL     = profile.url
            connectedToken   = token.access_token
            connectedProfile = profile
            tokenExpiresAt   = Date().addingTimeInterval(Double(token.expires_in))

            let result = try await engine.run(
                url: profile.url, token: token.access_token,
                includeMobile: includeMobileEAs
            ) { [weak self] status in
                await MainActor.run { self?.loadingMessage = status }
            }

            CacheService.save(result.eas, for: profile)
            withAnimation(.spring(duration: 0.5)) {
                extensionAttributes = result.eas
                lastScanDate        = Date()
                scanWarning         = result.warning
                isConnected         = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: Refresh
    @MainActor
    func refresh() async {
        guard let profile = connectedProfile,
              let secret  = KeychainService.shared.load(for: profile.id.uuidString) else { return }
        selectedEAIDs = []
        isLoading     = true
        errorMessage  = nil
        scanWarning   = nil
        do {
            loadingMessage = "Authenticating..."
            let token = try await api.authenticate(url: profile.url, clientID: profile.clientID, clientSecret: secret)
            connectedToken = token.access_token
            tokenExpiresAt = Date().addingTimeInterval(Double(token.expires_in))

            let result = try await engine.run(
                url: profile.url, token: token.access_token,
                includeMobile: includeMobileEAs
            ) { [weak self] status in
                await MainActor.run { self?.loadingMessage = status }
            }

            CacheService.save(result.eas, for: profile)
            withAnimation(.spring(duration: 0.4)) {
                extensionAttributes = result.eas
                lastScanDate        = Date()
                scanWarning         = result.warning
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: Token Auto-Refresh
    // Silently re-authenticates before delete operations if token has lapsed.
    @discardableResult
    private func ensureFreshToken() async throws -> String {
        guard tokenIsExpired, let profile = connectedProfile,
              let secret = KeychainService.shared.load(for: profile.id.uuidString)
        else { return connectedToken }
        await MainActor.run { loadingMessage = "Token expired — re-authenticating..." }
        let token = try await api.authenticate(url: profile.url, clientID: profile.clientID, clientSecret: secret)
        await MainActor.run {
            connectedToken = token.access_token
            tokenExpiresAt = Date().addingTimeInterval(Double(token.expires_in))
        }
        return token.access_token
    }

    // MARK: Disconnect
    @MainActor
    func disconnect() {
        withAnimation(.spring(duration: 0.4)) {
            isConnected         = false
            extensionAttributes = []
            selectedEA          = nil
            selectedEAIDs       = []
            connectedURL        = ""
            connectedToken      = ""
            connectedProfile    = nil
            tokenExpiresAt      = nil
            lastScanDate        = nil
            scanWarning         = nil
            deleteLog           = []
            filterStatus        = nil
            filterScope         = nil
            filterDataType      = nil
            searchText          = ""
            filterDisabledOnly  = false
        }
    }

    // MARK: EA Script Fetch (used by DetailView)
    func fetchEAScript(ea: ExtensionAttribute) async throws -> String? {
        ea.scope == .mobile
            ? try await api.fetchMobileEAScript(baseURL: connectedURL, token: connectedToken, id: ea.id)
            : try await api.fetchEAScript(baseURL: connectedURL, token: connectedToken, id: ea.id)
    }

    // MARK: Select All Safe (visible list only)
    func selectAllSafe() {
        filteredEAs.filter { $0.status == .safe }.forEach { selectedEAIDs.insert($0.id) }
    }

    // MARK: Bulk Delete
    @MainActor
    func deleteSelectedEAs() async {
        isLoading      = true
        loadingMessage = "Deleting \(selectedEAIDs.count) EAs..."
        _ = try? await ensureFreshToken()

        let toDelete = extensionAttributes.filter { selectedEAIDs.contains($0.id) }
        var deletedIDs = Set<Int>()
        var hitPermissionError = false

        for ea in toDelete {
            do {
                try await api.deleteEA(baseURL: connectedURL, token: connectedToken, id: ea.id)
                deletedIDs.insert(ea.id)
                deleteLog.insert(DeleteLogEntry(eaName: ea.name, eaID: ea.id, deletedAt: Date()), at: 0)
            } catch JamfAPIError.insufficientPermissions {
                hitPermissionError = true
                break
            } catch {
                // Individual EA failed — skip and continue
            }
        }
        if deleteLog.count > 50 { deleteLog = Array(deleteLog.prefix(50)) }

        if hitPermissionError {
            permissionError = """
                Your Jamf API role does not have permission to delete Extension Attributes.

                Go to Jamf Pro → Settings → API Roles & Clients and add the \
                "Delete Computer Extension Attributes" privilege to your API Role.

                No Extension Attributes were removed.
                """
        }

        extensionAttributes.removeAll { deletedIDs.contains($0.id) }
        if let sel = selectedEA, deletedIDs.contains(sel.id) { selectedEA = nil }
        selectedEAIDs = []
        isLoading = false
    }

    // MARK: Export — delegates to ExportService
    func exportCSV(eas list: [ExtensionAttribute]? = nil) {
        let content = ExportService.csv(eas: list ?? extensionAttributes)
        let suffix  = list != nil ? "_Selected" : ""
        ExportService.openTemp(content, filename: "NexusExport\(suffix).csv")
    }

    func exportJSON(eas list: [ExtensionAttribute]? = nil) {
        guard let content = ExportService.json(eas: list ?? extensionAttributes) else { return }
        let suffix = list != nil ? "_Selected" : ""
        ExportService.openTemp(content, filename: "NexusExport\(suffix).json")
    }

    func exportHTMLReport(eas list: [ExtensionAttribute]? = nil) {
        let content = ExportService.html(eas: list ?? extensionAttributes, serverURL: connectedURL)
        ExportService.saveHTMLWithPanel(content)
    }
}
