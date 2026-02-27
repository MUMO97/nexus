// JamfAPIService.swift
// Nexus — Jamf EA Dependency Analyzer
// Copyright © 2025 Murat Kolar. Licensed under GNU GPL v3.
// https://github.com/MUMO97/nexus

import Foundation

// MARK: - Errors
enum JamfAPIError: LocalizedError {
    case badURL
    case badResponse(Int, String = "") // HTTP status code + optional body
    case insufficientPermissions(String)

    var errorDescription: String? {
        switch self {
        case .badURL:
            return "Invalid Jamf URL."
        case .badResponse(let code, let body):
            let detail = body.isEmpty ? "" : "\n\n\(body)"
            switch code {
            case 400: return "HTTP 400 — Bad Request. Check Client ID and Secret.\(detail)"
            case 401: return "HTTP 401 — Unauthorized. Wrong Client ID or Client Secret.\(detail)"
            case 404: return "HTTP 404 — Not Found. Check your Jamf URL.\(detail)"
            case 500...599: return "HTTP \(code) — Jamf server error.\(detail)"
            default:  return "HTTP \(code) — Unexpected response.\(detail)"
            }
        case .insufficientPermissions(let endpoint):
            return """
                API permission error on: \(endpoint)

                Your Jamf API role is missing one or more required privileges. \
                Go to Jamf Pro → Settings → API Roles & Clients and ensure your role includes:

                • Read Computer Extension Attributes
                • Read Mobile Device Extension Attributes (optional, for mobile EAs)
                • Read Computer Groups
                • Read Mobile Device Groups (optional, for mobile EAs)
                • Read Advanced Computer Searches
                • Read Advanced Mobile Device Searches (optional, for mobile EAs)
                • Read Policies
                • Read macOS Configuration Profiles
                • Read Mobile Device Configuration Profiles (optional, for mobile EAs)
                • Read Restricted Software (optional)
                • Read Patch Policies (optional)
                • Delete Computer Extension Attributes (optional, for bulk delete)
                """
        }
    }
}

// MARK: - Private response types (file-level so task group closures can access them without actor isolation issues)
private struct EAListResponse: Codable, Sendable {
    struct EAItem: Codable, Sendable { let id: Int; let name: String }
    let computer_extension_attributes: [EAItem]
}
private struct EADetailResponse: Codable, Sendable {
    struct Detail: Codable, Sendable {
        let id: Int; let name: String
        let enabled: Bool?; let data_type: String?
    }
    let computer_extension_attribute: Detail
}

// MARK: - TLS session delegate
// Session-level delegate — server trust (TLS) challenges are session-level, not task-level.
// Handles hostname mismatch for custom-domain Jamf Cloud instances
// (e.g. a custom domain whose server presents a *.jamfcloud.com cert).
// SecPolicyCreateBasicX509() validates the certificate chain without checking hostname.
// nonisolated on every method because URLSession calls them from background threads and
// SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor would otherwise make them @MainActor.
private final class JamfTLSDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate {

    nonisolated func urlSession(_ session: URLSession,
                                didReceive challenge: URLAuthenticationChallenge,
                                completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        handle(challenge, completionHandler: completionHandler)
    }

    nonisolated func urlSession(_ session: URLSession,
                                task: URLSessionTask,
                                didReceive challenge: URLAuthenticationChallenge,
                                completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        handle(challenge, completionHandler: completionHandler)
    }

    nonisolated private func handle(_ challenge: URLAuthenticationChallenge,
                                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        SecTrustSetPolicies(trust, [SecPolicyCreateBasicX509()] as CFArray)
        var cfError: CFError?
        _ = SecTrustEvaluateWithError(trust, &cfError)
        completionHandler(.useCredential, URLCredential(trust: trust))
    }

    nonisolated func urlSession(_ session: URLSession,
                                task: URLSessionTask,
                                willPerformHTTPRedirection response: HTTPURLResponse,
                                newRequest request: URLRequest,
                                completionHandler: @escaping (URLRequest?) -> Void) {
        guard let original = task.originalRequest,
              original.httpMethod == "POST" else {
            completionHandler(request)
            return
        }
        var kept = request
        kept.httpMethod = "POST"
        kept.httpBody   = original.httpBody
        if let ct = original.value(forHTTPHeaderField: "Content-Type") {
            kept.setValue(ct, forHTTPHeaderField: "Content-Type")
        }
        completionHandler(kept)
    }
}

// MARK: - Service
final class JamfAPIService {
    private let session: URLSession = {
        let delegate = JamfTLSDelegate()
        return URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
    }()

    // MARK: Authenticate
    func authenticate(url: String, clientID: String, clientSecret: String) async throws -> JamfTokenResponse {
        let base = url.trimmingCharacters(in: .whitespacesAndNewlines)
                      .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let authURL = URL(string: "\(base)/api/oauth/token") else { throw JamfAPIError.badURL }
        var req = URLRequest(url: authURL)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = [
            "grant_type=client_credentials",
            "client_id=\(clientID.formEncoded)",
            "client_secret=\(clientSecret.formEncoded)"
        ].joined(separator: "&").data(using: .utf8)
        let (data, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw JamfAPIError.badResponse(http.statusCode, body)
        }
        return try JSONDecoder().decode(JamfTokenResponse.self, from: data)
    }

    // MARK: Fetch EAs
    // Fetches the list then detail for each EA in batches of 10 to avoid overwhelming
    // the Jamf API with hundreds of simultaneous requests.
    // onProgress(completed, total) is called after each batch so the UI can show progress.
    func fetchEAs(url: String, token: String,
                  onProgress: ((Int, Int) async -> Void)? = nil) async throws -> [ExtensionAttribute] {
        let url = url.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let listData = try await get("\(url)/JSSResource/computerextensionattributes", token: token)
        let list = try JSONDecoder().decode(EAListResponse.self, from: listData)
        let items = list.computer_extension_attributes
        let total = items.count

        var eas: [ExtensionAttribute] = []
        let batchSize = 20

        for batchStart in stride(from: 0, to: total, by: batchSize) {
            let batchEnd  = min(batchStart + batchSize, total)
            let batch     = Array(items[batchStart..<batchEnd])

            // Non-throwing group — a single slow/failing EA detail fetch
            // cannot block or cancel the rest of the batch.
            await withTaskGroup(of: (EAListResponse.EAItem, Data?).self) { group in
                for item in batch {
                    group.addTask {
                        let detail = try? await self.get(
                            "\(url)/JSSResource/computerextensionattributes/id/\(item.id)",
                            token: token)
                        return (item, detail)
                    }
                }
                for await (item, data) in group {
                    if let data,
                       let decoded = try? JSONDecoder().decode(EADetailResponse.self, from: data) {
                        let d = decoded.computer_extension_attribute
                        eas.append(ExtensionAttribute(id: d.id, name: d.name, data_type: d.data_type, enabled: d.enabled ?? true))
                    } else {
                        eas.append(ExtensionAttribute(id: item.id, name: item.name, data_type: nil, enabled: true))
                    }
                }
            }

            await onProgress?(batchEnd, total)
        }

        return eas.sorted { $0.id < $1.id }
    }

    // MARK: Fetch All Dependencies
    // Uses native XML for all dependency scanning — avoids the Jamf Classic API JSON
    // conversion bug where a single-item list is serialised as an object instead of an array,
    // silently dropping all criteria when a Smart Group has exactly one criterion.
    // Each scanner is independent: a permission error returns [] rather than failing the scan.
    // onProgress is called with a status string before each phase so the UI stays responsive.
    func fetchDependencies(baseURL: String, token: String, eas: [ExtensionAttribute],
                           onProgress: ((String) async -> Void)? = nil) async throws -> [Int: [DependencyItem]] {
        let baseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        // uniquingKeysWith keeps the first EA when two share the same lowercased name,
        // avoiding a fatal crash on duplicate keys.
        let nameToID: [String: Int] = Dictionary(
            eas.map { ($0.name.lowercased().trimmingCharacters(in: .whitespaces), $0.id) },
            uniquingKeysWith: { first, _ in first }
        )

        // All six phases run concurrently — each is independent and failure-safe.
        await onProgress?("Scanning Smart Groups, Searches, Policies, Profiles, Restricted Software & Patch Policies...")
        async let sgTask   = scanSmartGroups(baseURL: baseURL, token: token, nameToID: nameToID)
        async let asTask   = scanAdvancedSearches(baseURL: baseURL, token: token, nameToID: nameToID)
        async let polTask  = scanPolicies(baseURL: baseURL, token: token, nameToID: nameToID)
        async let profTask = scanConfigProfiles(baseURL: baseURL, token: token, nameToID: nameToID)
        async let rsTask   = scanRestrictedSoftware(baseURL: baseURL, token: token, nameToID: nameToID)
        async let ppTask   = scanPatchPolicies(baseURL: baseURL, token: token, nameToID: nameToID)

        let sg   = (try? await sgTask)   ?? []
        let as_  = (try? await asTask)   ?? []
        let pol  = (try? await polTask)  ?? []
        let prof = (try? await profTask) ?? []
        let rs   = (try? await rsTask)   ?? []
        let pp   = (try? await ppTask)   ?? []

        var result: [Int: [DependencyItem]] = [:]
        for (eaID, item) in sg + as_ + pol + prof + rs + pp {
            result[eaID, default: []].append(item)
        }
        return result
    }

    // MARK: Smart Groups — XML + XPath
    private func scanSmartGroups(baseURL: String, token: String, nameToID: [String: Int]) async throws -> [(Int, DependencyItem)] {
        let data = try await get("\(baseURL)/JSSResource/computergroups", token: token)

        struct GL: Codable {
            struct GI: Codable { let id: Int; let name: String; let is_smart: Bool? }
            let computer_groups: [GI]
        }

        let list = try JSONDecoder().decode(GL.self, from: data)
        let smarts = list.computer_groups.filter { $0.is_smart == true }

        return await withTaskGroup(of: [(Int, DependencyItem)].self) { group in
            for sg in smarts {
                group.addTask {
                    (try? await self.fetchGroupDeps(baseURL: baseURL, token: token,
                                                    groupID: sg.id, groupName: sg.name,
                                                    nameToID: nameToID)) ?? []
                }
            }
            var all: [(Int, DependencyItem)] = []
            for await pairs in group { all.append(contentsOf: pairs) }
            return all
        }
    }

    private func fetchGroupDeps(baseURL: String, token: String, groupID: Int, groupName: String, nameToID: [String: Int]) async throws -> [(Int, DependencyItem)] {
        // XML avoids the JSON single-object-vs-array bug entirely.
        // XPath //criteria/criterion/name matches every criterion regardless of count.
        let doc = try await getXML("\(baseURL)/JSSResource/computergroups/id/\(groupID)", token: token)
        guard let nodes = try? doc.nodes(forXPath: "//criteria/criterion/name") else { return [] }

        return nodes.compactMap { node in
            let key = (node.stringValue ?? "").lowercased().trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty, let eaID = nameToID[key] else { return nil }
            return (eaID, DependencyItem(sourceID: groupID, name: groupName, type: .smartGroup))
        }
    }

    // MARK: Advanced Searches — XML + XPath
    private func scanAdvancedSearches(baseURL: String, token: String, nameToID: [String: Int]) async throws -> [(Int, DependencyItem)] {
        let data = try await get("\(baseURL)/JSSResource/advancedcomputersearches", token: token)

        struct SL: Codable {
            struct SI: Codable { let id: Int; let name: String }
            let advanced_computer_searches: [SI]
        }

        let list = try JSONDecoder().decode(SL.self, from: data)

        return await withTaskGroup(of: [(Int, DependencyItem)].self) { group in
            for s in list.advanced_computer_searches {
                group.addTask {
                    (try? await self.fetchSearchDeps(baseURL: baseURL, token: token,
                                                     searchID: s.id, searchName: s.name,
                                                     nameToID: nameToID)) ?? []
                }
            }
            var all: [(Int, DependencyItem)] = []
            for await pairs in group { all.append(contentsOf: pairs) }
            return all
        }
    }

    private func fetchSearchDeps(baseURL: String, token: String, searchID: Int, searchName: String, nameToID: [String: Int]) async throws -> [(Int, DependencyItem)] {
        let doc = try await getXML("\(baseURL)/JSSResource/advancedcomputersearches/id/\(searchID)", token: token)
        var results: [(Int, DependencyItem)] = []

        // Criteria — EA used as a filter condition
        if let nodes = try? doc.nodes(forXPath: "//criteria/criterion/name") {
            for node in nodes {
                let key = (node.stringValue ?? "").lowercased().trimmingCharacters(in: .whitespaces)
                if let eaID = nameToID[key] {
                    results.append((eaID, DependencyItem(sourceID: searchID, name: searchName, type: .advancedSearch)))
                }
            }
        }

        // Display fields — EA used as a results column
        if let nodes = try? doc.nodes(forXPath: "//display_fields/display_field/name") {
            for node in nodes {
                let key = (node.stringValue ?? "").lowercased().trimmingCharacters(in: .whitespaces)
                if let eaID = nameToID[key] {
                    results.append((eaID, DependencyItem(sourceID: searchID, name: searchName, type: .advancedSearchDisplay)))
                }
            }
        }

        return results
    }

    // MARK: Policies — XML full-document name scan
    // Policies scope to Smart Groups; the Smart Group scanner already catches the EA→Group link.
    // This additional scan catches any direct EA name reference anywhere in the policy XML
    // (script parameter labels, scope limitations, etc.).
    // Returns [] if the API client lacks Read Policies permission — does not abort the scan.
    private func scanPolicies(baseURL: String, token: String, nameToID: [String: Int]) async throws -> [(Int, DependencyItem)] {
        guard let data = try? await get("\(baseURL)/JSSResource/policies", token: token) else { return [] }

        struct PL: Codable {
            struct PI: Codable { let id: Int; let name: String }
            let policies: [PI]
        }

        guard let list = try? JSONDecoder().decode(PL.self, from: data) else { return [] }

        return await withTaskGroup(of: [(Int, DependencyItem)].self) { group in
            for p in list.policies {
                group.addTask {
                    (try? await self.fetchPolicyDeps(baseURL: baseURL, token: token,
                                                     policyID: p.id, policyName: p.name,
                                                     nameToID: nameToID)) ?? []
                }
            }
            var all: [(Int, DependencyItem)] = []
            for await pairs in group { all.append(contentsOf: pairs) }
            return all
        }
    }

    private func fetchPolicyDeps(baseURL: String, token: String, policyID: Int, policyName: String, nameToID: [String: Int]) async throws -> [(Int, DependencyItem)] {
        let doc = try await getXML("\(baseURL)/JSSResource/policies/id/\(policyID)", token: token)
        guard let nodes = try? doc.nodes(forXPath: "//*[local-name()='name']") else { return [] }

        var seen = Set<Int>()
        return nodes.compactMap { node in
            let key = (node.stringValue ?? "").lowercased().trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty, let eaID = nameToID[key], !seen.contains(eaID) else { return nil }
            seen.insert(eaID)
            return (eaID, DependencyItem(sourceID: policyID, name: policyName, type: .policy))
        }
    }

    // MARK: Configuration Profiles — XML full-document name scan
    // Returns [] if the API client lacks Read Config Profiles permission.
    private func scanConfigProfiles(baseURL: String, token: String, nameToID: [String: Int]) async throws -> [(Int, DependencyItem)] {
        guard let data = try? await get("\(baseURL)/JSSResource/osxconfigurationprofiles", token: token) else { return [] }

        struct CPL: Codable {
            struct CPI: Codable { let id: Int; let name: String }
            let os_x_configuration_profiles: [CPI]
        }

        guard let list = try? JSONDecoder().decode(CPL.self, from: data) else { return [] }

        return await withTaskGroup(of: [(Int, DependencyItem)].self) { group in
            for p in list.os_x_configuration_profiles {
                group.addTask {
                    (try? await self.fetchConfigProfileDeps(baseURL: baseURL, token: token,
                                                            profileID: p.id, profileName: p.name,
                                                            nameToID: nameToID)) ?? []
                }
            }
            var all: [(Int, DependencyItem)] = []
            for await pairs in group { all.append(contentsOf: pairs) }
            return all
        }
    }

    private func fetchConfigProfileDeps(baseURL: String, token: String, profileID: Int, profileName: String, nameToID: [String: Int]) async throws -> [(Int, DependencyItem)] {
        let doc = try await getXML("\(baseURL)/JSSResource/osxconfigurationprofiles/id/\(profileID)", token: token)
        guard let nodes = try? doc.nodes(forXPath: "//*[local-name()='name']") else { return [] }

        var seen = Set<Int>()
        return nodes.compactMap { node in
            let key = (node.stringValue ?? "").lowercased().trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty, let eaID = nameToID[key], !seen.contains(eaID) else { return nil }
            seen.insert(eaID)
            return (eaID, DependencyItem(sourceID: profileID, name: profileName, type: .configProfile))
        }
    }

    // MARK: Restricted Software — XML full-document name scan
    // Restricted Software rules can scope via Smart Groups (already caught) but also reference
    // EAs directly in scope/exclusion criteria. Returns [] if endpoint is unavailable or
    // the API client lacks Read Restricted Software permission.
    private func scanRestrictedSoftware(baseURL: String, token: String, nameToID: [String: Int]) async throws -> [(Int, DependencyItem)] {
        guard let data = try? await get("\(baseURL)/JSSResource/restrictedsoftware", token: token) else { return [] }

        struct RSL: Codable {
            struct RSI: Codable { let id: Int; let name: String }
            let restricted_software: [RSI]
        }

        guard let list = try? JSONDecoder().decode(RSL.self, from: data) else { return [] }

        return await withTaskGroup(of: [(Int, DependencyItem)].self) { group in
            for rs in list.restricted_software {
                group.addTask {
                    (try? await self.fetchRestrictedSoftwareDeps(baseURL: baseURL, token: token,
                                                                 rsID: rs.id, rsName: rs.name,
                                                                 nameToID: nameToID)) ?? []
                }
            }
            var all: [(Int, DependencyItem)] = []
            for await pairs in group { all.append(contentsOf: pairs) }
            return all
        }
    }

    private func fetchRestrictedSoftwareDeps(baseURL: String, token: String, rsID: Int, rsName: String, nameToID: [String: Int]) async throws -> [(Int, DependencyItem)] {
        let doc = try await getXML("\(baseURL)/JSSResource/restrictedsoftware/id/\(rsID)", token: token)
        guard let nodes = try? doc.nodes(forXPath: "//*[local-name()='name']") else { return [] }

        var seen = Set<Int>()
        return nodes.compactMap { node in
            let key = (node.stringValue ?? "").lowercased().trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty, let eaID = nameToID[key], !seen.contains(eaID) else { return nil }
            seen.insert(eaID)
            return (eaID, DependencyItem(sourceID: rsID, name: rsName, type: .restrictedSoftware))
        }
    }

    // MARK: Patch Policies — XML full-document name scan
    // Patch Policies can scope to Smart Groups that reference EAs and may also contain
    // direct EA references in their scope XML. Returns [] if Patch Management is not
    // enabled or the API client lacks permission — does not abort the scan.
    private func scanPatchPolicies(baseURL: String, token: String, nameToID: [String: Int]) async throws -> [(Int, DependencyItem)] {
        guard let data = try? await get("\(baseURL)/JSSResource/patchpolicies", token: token) else { return [] }

        struct PPL: Codable {
            struct PPI: Codable { let id: Int; let name: String }
            let patch_policies: [PPI]
        }

        guard let list = try? JSONDecoder().decode(PPL.self, from: data) else { return [] }

        return await withTaskGroup(of: [(Int, DependencyItem)].self) { group in
            for pp in list.patch_policies {
                group.addTask {
                    (try? await self.fetchPatchPolicyDeps(baseURL: baseURL, token: token,
                                                          ppID: pp.id, ppName: pp.name,
                                                          nameToID: nameToID)) ?? []
                }
            }
            var all: [(Int, DependencyItem)] = []
            for await pairs in group { all.append(contentsOf: pairs) }
            return all
        }
    }

    private func fetchPatchPolicyDeps(baseURL: String, token: String, ppID: Int, ppName: String, nameToID: [String: Int]) async throws -> [(Int, DependencyItem)] {
        let doc = try await getXML("\(baseURL)/JSSResource/patchpolicies/id/\(ppID)", token: token)
        guard let nodes = try? doc.nodes(forXPath: "//*[local-name()='name']") else { return [] }

        var seen = Set<Int>()
        return nodes.compactMap { node in
            let key = (node.stringValue ?? "").lowercased().trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty, let eaID = nameToID[key], !seen.contains(eaID) else { return nil }
            seen.insert(eaID)
            return (eaID, DependencyItem(sourceID: ppID, name: ppName, type: .patchPolicy))
        }
    }

    // MARK: Delete EA
    func deleteEA(baseURL: String, token: String, id: Int) async throws {
        guard let url = URL(string: "\(baseURL)/JSSResource/computerextensionattributes/id/\(id)") else {
            throw JamfAPIError.badURL
        }
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (_, response) = try await session.data(for: req)
        try validateDelete(response)
    }

    // Separate validator for DELETE — treats 401, 403, and any other 4xx as a
    // permissions failure so the user sees an actionable error rather than a generic one.
    private func validateDelete(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw JamfAPIError.badResponse(0) }
        if (400...499).contains(http.statusCode) {
            throw JamfAPIError.insufficientPermissions("/JSSResource/computerextensionattributes/id/…")
        }
        guard (200...299).contains(http.statusCode) else { throw JamfAPIError.badResponse(http.statusCode) }
    }

    // MARK: Helpers
    private func get(_ urlString: String, token: String) async throws -> Data {
        guard let url = URL(string: urlString) else { throw JamfAPIError.badURL }
        var req = URLRequest(url: url, timeoutInterval: 30)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: req)
        try validate(response, endpoint: urlString)
        return data
    }

    private func getXML(_ urlString: String, token: String) async throws -> XMLDocument {
        guard let url = URL(string: urlString) else { throw JamfAPIError.badURL }
        var req = URLRequest(url: url, timeoutInterval: 30)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("text/xml", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: req)
        try validate(response, endpoint: urlString)
        return try XMLDocument(data: data, options: .nodeLoadExternalEntitiesNever)
    }

    private func validate(_ response: URLResponse, endpoint: String = "") throws {
        guard let http = response as? HTTPURLResponse else { throw JamfAPIError.badResponse(0) }
        // Jamf Classic API returns 401 (not 403) when a valid token lacks role permissions
        if http.statusCode == 401 || http.statusCode == 403 {
            // Strip base URL from endpoint for a cleaner display
            let path = URL(string: endpoint)?.path ?? endpoint
            throw JamfAPIError.insufficientPermissions(path.isEmpty ? endpoint : path)
        }
        guard (200...299).contains(http.statusCode) else { throw JamfAPIError.badResponse(http.statusCode) }
    }

    // MARK: Mobile Device EAs
    // Mirrors the computer EA scanner but against /JSSResource/mobiledeviceextensionattributes.
    // Returns [] silently if the API client lacks permission.
    func fetchMobileEAs(url: String, token: String,
                        onProgress: ((Int, Int) async -> Void)? = nil) async throws -> [ExtensionAttribute] {
        let baseURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
                        .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        guard let data = try? await get("\(baseURL)/JSSResource/mobiledeviceextensionattributes", token: token) else { return [] }

        struct MDEAList: Codable, Sendable {
            struct Item: Codable, Sendable { let id: Int; let name: String }
            let mobile_device_extension_attributes: [Item]
        }
        guard let list = try? JSONDecoder().decode(MDEAList.self, from: data) else { return [] }

        let items = list.mobile_device_extension_attributes
        let total = items.count
        var eas: [ExtensionAttribute] = []

        let batchSize = 20
        for batchStart in stride(from: 0, to: total, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, total)
            let batch = Array(items[batchStart..<batchEnd])

            let batchResults = await withTaskGroup(of: ExtensionAttribute?.self, returning: [ExtensionAttribute].self) { group in
                for item in batch {
                    group.addTask {
                        struct MDEADetail: Codable, Sendable {
                            struct D: Codable, Sendable { let id: Int; let name: String; let data_type: String?; let enabled: Bool? }
                            let mobile_device_extension_attribute: D
                        }
                        if let detailData = try? await self.get("\(baseURL)/JSSResource/mobiledeviceextensionattributes/id/\(item.id)", token: token),
                           let d = try? JSONDecoder().decode(MDEADetail.self, from: detailData) {
                            var ea = ExtensionAttribute(id: d.mobile_device_extension_attribute.id,
                                                        name: d.mobile_device_extension_attribute.name,
                                                        data_type: d.mobile_device_extension_attribute.data_type,
                                                        enabled: d.mobile_device_extension_attribute.enabled ?? true)
                            ea.scope = .mobile
                            return ea
                        }
                        var ea = ExtensionAttribute(id: item.id, name: item.name, data_type: nil, enabled: true)
                        ea.scope = .mobile
                        return ea
                    }
                }
                var collected: [ExtensionAttribute] = []
                for await ea in group { if let ea { collected.append(ea) } }
                return collected
            }
            eas.append(contentsOf: batchResults)
            await onProgress?(batchEnd, total)
        }
        return eas.sorted { $0.id < $1.id }
    }

    // MARK: Mobile Device Dependencies
    // Scans Mobile Smart Groups, Mobile Advanced Searches, and Mobile Config Profiles.
    // All three phases run concurrently. Returns [] per phase on permission error.
    func fetchMobileDependencies(baseURL: String, token: String, eas: [ExtensionAttribute],
                                 onProgress: ((String) async -> Void)? = nil) async throws -> [Int: [DependencyItem]] {
        let baseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
                             .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let nameToID: [String: Int] = Dictionary(
            eas.map { ($0.name.lowercased().trimmingCharacters(in: .whitespaces), $0.id) },
            uniquingKeysWith: { first, _ in first }
        )

        await onProgress?("Scanning Mobile Smart Groups, Searches & Profiles...")
        async let msgTask  = scanMobileSmartGroups(baseURL: baseURL, token: token, nameToID: nameToID)
        async let masTask  = scanMobileAdvancedSearches(baseURL: baseURL, token: token, nameToID: nameToID)
        async let mcpTask  = scanMobileConfigProfiles(baseURL: baseURL, token: token, nameToID: nameToID)

        let msg = (try? await msgTask) ?? []
        let mas = (try? await masTask) ?? []
        let mcp = (try? await mcpTask) ?? []

        var result: [Int: [DependencyItem]] = [:]
        for (eaID, item) in msg + mas + mcp {
            result[eaID, default: []].append(item)
        }
        return result
    }

    private func scanMobileSmartGroups(baseURL: String, token: String, nameToID: [String: Int]) async throws -> [(Int, DependencyItem)] {
        guard let data = try? await get("\(baseURL)/JSSResource/mobiledevicegroups", token: token) else { return [] }

        struct MGL: Codable {
            struct MGI: Codable { let id: Int; let name: String; let is_smart: Bool? }
            let mobile_device_groups: [MGI]
        }
        guard let list = try? JSONDecoder().decode(MGL.self, from: data) else { return [] }
        let smarts = list.mobile_device_groups.filter { $0.is_smart == true }

        return await withTaskGroup(of: [(Int, DependencyItem)].self) { group in
            for sg in smarts {
                group.addTask {
                    guard let doc = try? await self.getXML("\(baseURL)/JSSResource/mobiledevicegroups/id/\(sg.id)", token: token),
                          let nodes = try? doc.nodes(forXPath: "//criteria/criterion/name") else { return [] }
                    var seen = Set<Int>()
                    return nodes.compactMap { node in
                        let key = (node.stringValue ?? "").lowercased().trimmingCharacters(in: .whitespaces)
                        guard !key.isEmpty, let eaID = nameToID[key], !seen.contains(eaID) else { return nil }
                        seen.insert(eaID)
                        return (eaID, DependencyItem(sourceID: sg.id, name: sg.name, type: .mobileSmartGroup))
                    }
                }
            }
            var all: [(Int, DependencyItem)] = []
            for await pairs in group { all.append(contentsOf: pairs) }
            return all
        }
    }

    private func scanMobileAdvancedSearches(baseURL: String, token: String, nameToID: [String: Int]) async throws -> [(Int, DependencyItem)] {
        guard let data = try? await get("\(baseURL)/JSSResource/advancedmobiledevicesearches", token: token) else { return [] }

        struct MASL: Codable {
            struct MASI: Codable { let id: Int; let name: String }
            let advanced_mobile_device_searches: [MASI]
        }
        guard let list = try? JSONDecoder().decode(MASL.self, from: data) else { return [] }

        return await withTaskGroup(of: [(Int, DependencyItem)].self) { group in
            for s in list.advanced_mobile_device_searches {
                group.addTask {
                    guard let doc = try? await self.getXML("\(baseURL)/JSSResource/advancedmobiledevicesearches/id/\(s.id)", token: token) else { return [] }
                    var results: [(Int, DependencyItem)] = []
                    if let nodes = try? doc.nodes(forXPath: "//criteria/criterion/name") {
                        for node in nodes {
                            let key = (node.stringValue ?? "").lowercased().trimmingCharacters(in: .whitespaces)
                            if let eaID = nameToID[key] {
                                results.append((eaID, DependencyItem(sourceID: s.id, name: s.name, type: .mobileAdvancedSearch)))
                            }
                        }
                    }
                    return results
                }
            }
            var all: [(Int, DependencyItem)] = []
            for await pairs in group { all.append(contentsOf: pairs) }
            return all
        }
    }

    private func scanMobileConfigProfiles(baseURL: String, token: String, nameToID: [String: Int]) async throws -> [(Int, DependencyItem)] {
        guard let data = try? await get("\(baseURL)/JSSResource/mobiledeviceconfigurationprofiles", token: token) else { return [] }

        struct MCPL: Codable {
            struct MCPI: Codable { let id: Int; let name: String }
            let configuration_profiles: [MCPI]
        }
        guard let list = try? JSONDecoder().decode(MCPL.self, from: data) else { return [] }

        return await withTaskGroup(of: [(Int, DependencyItem)].self) { group in
            for p in list.configuration_profiles {
                group.addTask {
                    guard let doc = try? await self.getXML("\(baseURL)/JSSResource/mobiledeviceconfigurationprofiles/id/\(p.id)", token: token),
                          let nodes = try? doc.nodes(forXPath: "//*[local-name()='name']") else { return [] }
                    var seen = Set<Int>()
                    return nodes.compactMap { node in
                        let key = (node.stringValue ?? "").lowercased().trimmingCharacters(in: .whitespaces)
                        guard !key.isEmpty, let eaID = nameToID[key], !seen.contains(eaID) else { return nil }
                        seen.insert(eaID)
                        return (eaID, DependencyItem(sourceID: p.id, name: p.name, type: .mobileConfigProfile))
                    }
                }
            }
            var all: [(Int, DependencyItem)] = []
            for await pairs in group { all.append(contentsOf: pairs) }
            return all
        }
    }

    // MARK: EA Script Body
    // Fetches the input_type/script element for a computer EA. Returns nil if not a script EA.
    func fetchEAScript(baseURL: String, token: String, id: Int) async throws -> String? {
        let baseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
                             .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let doc = try await getXML("\(baseURL)/JSSResource/computerextensionattributes/id/\(id)", token: token)
        // Script body lives at /computer_extension_attribute/input_type/script
        if let node = try? doc.nodes(forXPath: "//input_type/script").first,
           let script = node.stringValue, !script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return script
        }
        return nil
    }

    // Mobile EA script equivalent
    func fetchMobileEAScript(baseURL: String, token: String, id: Int) async throws -> String? {
        let baseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
                             .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let doc = try await getXML("\(baseURL)/JSSResource/mobiledeviceextensionattributes/id/\(id)", token: token)
        if let node = try? doc.nodes(forXPath: "//input_type/script").first,
           let script = node.stringValue, !script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return script
        }
        return nil
    }

    // MARK: Update EA Script (Pro — script editing)
    func updateEAScript(baseURL: String, token: String, id: Int, newScript: String, scope: EAScope) async throws {
        let base = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
                          .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let endpoint = scope == .mobile
            ? "\(base)/JSSResource/mobiledeviceextensionattributes/id/\(id)"
            : "\(base)/JSSResource/computerextensionattributes/id/\(id)"
        guard let url = URL(string: endpoint) else { throw JamfAPIError.badURL }

        // Only update the script element; Jamf merges the rest
        let escapedScript = newScript
            .replacingOccurrences(of: "&",  with: "&amp;")
            .replacingOccurrences(of: "<",  with: "&lt;")
            .replacingOccurrences(of: ">",  with: "&gt;")
        let xmlBody = scope == .mobile
            ? "<mobile_device_extension_attribute><input_type><script>\(escapedScript)</script></input_type></mobile_device_extension_attribute>"
            : "<computer_extension_attribute><input_type><script>\(escapedScript)</script></input_type></computer_extension_attribute>"

        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("text/xml", forHTTPHeaderField: "Content-Type")
        req.httpBody = xmlBody.data(using: .utf8)

        let (_, response) = try await session.data(for: req)
        try validate(response, endpoint: endpoint)
    }
}

private extension String {
    /// Percent-encodes a string for use as a value in application/x-www-form-urlencoded bodies.
    /// Encodes everything except unreserved characters (RFC 3986: A-Z a-z 0-9 - _ . ~).
    /// This matches curl --data-urlencode behaviour and correctly encodes + as %2B.
    var formEncoded: String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return addingPercentEncoding(withAllowedCharacters: allowed) ?? self
    }
}
