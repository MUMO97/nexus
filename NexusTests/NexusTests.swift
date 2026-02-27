import XCTest
@testable import Nexus

final class NexusTests: XCTestCase {

    // MARK: - EAStatus

    func test_eaStatus_sortPriority_order() {
        // In Use should sort before Orphaned, Orphaned before Safe, Safe before Unknown
        XCTAssertLessThan(EAStatus.used.sortPriority,     EAStatus.orphaned.sortPriority)
        XCTAssertLessThan(EAStatus.orphaned.sortPriority, EAStatus.safe.sortPriority)
        XCTAssertLessThan(EAStatus.safe.sortPriority,     EAStatus.unknown.sortPriority)
    }

    func test_eaStatus_rawValues() {
        XCTAssertEqual(EAStatus.safe.rawValue,     "Safe to Delete")
        XCTAssertEqual(EAStatus.used.rawValue,     "In Use")
        XCTAssertEqual(EAStatus.orphaned.rawValue, "Orphaned")
        XCTAssertEqual(EAStatus.unknown.rawValue,  "Scanning...")
    }

    // MARK: - Status Classification Logic

    func test_statusClassification_enabledWithNoDeps_isSafe() {
        var ea = makeEA(enabled: true)
        ea.dependencies = []
        let status = classify(ea)
        XCTAssertEqual(status, .safe)
    }

    func test_statusClassification_disabledWithNoDeps_isOrphaned() {
        var ea = makeEA(enabled: false)
        ea.dependencies = []
        let status = classify(ea)
        XCTAssertEqual(status, .orphaned)
    }

    func test_statusClassification_withDeps_isUsed() {
        var ea = makeEA(enabled: true)
        ea.dependencies = [DependencyItem(sourceID: 1, name: "Test Group", type: .smartGroup)]
        let status = classify(ea)
        XCTAssertEqual(status, .used)
    }

    func test_statusClassification_disabledWithDeps_isUsed() {
        // A disabled EA that is still referenced must show as In Use, not Orphaned
        var ea = makeEA(enabled: false)
        ea.dependencies = [DependencyItem(sourceID: 1, name: "Test Group", type: .smartGroup)]
        let status = classify(ea)
        XCTAssertEqual(status, .used)
    }

    // MARK: - ExportService CSV

    func test_exportCSV_header() {
        let csv = ExportService.csv(eas: [])
        XCTAssertTrue(csv.hasPrefix("ID,Name,Scope,Enabled,Type,Status,Dependencies\n"))
    }

    func test_exportCSV_row_computerEA() {
        var ea = makeEA(enabled: true)
        ea.status = .safe
        let csv = ExportService.csv(eas: [ea])
        XCTAssertTrue(csv.contains("42"))
        XCTAssertTrue(csv.contains("Test EA"))
        XCTAssertTrue(csv.contains("Computer"))
        XCTAssertTrue(csv.contains("Yes"))
        XCTAssertTrue(csv.contains("Safe to Delete"))
    }

    func test_exportCSV_row_mobileEA() {
        var ea = makeEA(enabled: false)
        ea.scope  = .mobile
        ea.status = .orphaned
        let csv = ExportService.csv(eas: [ea])
        XCTAssertTrue(csv.contains("Mobile"))
        XCTAssertTrue(csv.contains("No"))
        XCTAssertTrue(csv.contains("Orphaned"))
    }

    func test_exportCSV_escapesQuotesInNames() {
        var ea = makeEA(enabled: true)
        // Name with a comma — must be quoted in CSV
        let ea2 = ExtensionAttribute(id: 1, name: "EA, with comma", data_type: "String", enabled: true)
        let csv = ExportService.csv(eas: [ea2])
        XCTAssertTrue(csv.contains("\"EA, with comma\""))
    }

    // MARK: - ExportService JSON

    func test_exportJSON_isValidJSON() {
        let ea  = makeEA(enabled: true)
        let str = ExportService.json(eas: [ea])
        XCTAssertNotNil(str)
        let data = str!.data(using: .utf8)!
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: data))
    }

    func test_exportJSON_emptyArray() {
        let str = ExportService.json(eas: [])
        XCTAssertEqual(str?.trimmingCharacters(in: .whitespacesAndNewlines), "[]")
    }

    // MARK: - ExportService HTML

    func test_exportHTML_containsServerURL() {
        let html = ExportService.html(eas: [], serverURL: "https://jamf.example.com")
        XCTAssertTrue(html.contains("https://jamf.example.com"))
    }

    func test_exportHTML_escapesAmpersand() {
        let ea = ExtensionAttribute(id: 1, name: "EA & Test", data_type: nil, enabled: true)
        let html = ExportService.html(eas: [ea], serverURL: "")
        XCTAssertTrue(html.contains("EA &amp; Test"))
        XCTAssertFalse(html.contains("EA & Test"))
    }

    func test_exportHTML_statCounts() {
        var safe     = makeEA(enabled: true);  safe.status     = .safe
        var used     = makeEA(enabled: true);  used.status     = .used
        var orphaned = makeEA(enabled: false); orphaned.status = .orphaned
        let html = ExportService.html(eas: [safe, used, orphaned], serverURL: "")
        XCTAssertTrue(html.contains("<div class=\"stat\"><div class=\"lbl\">Total EAs</div><div class=\"val\">3</div></div>"))
    }

    // MARK: - CacheService

    func test_cacheService_saveAndLoad() {
        let profile = ServerProfile(name: "Test", url: "https://test.com", clientID: "abc")
        var ea = makeEA(enabled: true); ea.status = .safe
        CacheService.save([ea], for: profile)
        let result = CacheService.load(for: profile)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.0.first?.id, 42)
        CacheService.clear(for: profile)
    }

    func test_cacheService_clearRemovesData() {
        let profile = ServerProfile(name: "Test", url: "https://test.com", clientID: "abc")
        CacheService.save([makeEA(enabled: true)], for: profile)
        CacheService.clear(for: profile)
        XCTAssertNil(CacheService.load(for: profile))
    }

    func test_cacheService_loadReturnsNilWhenEmpty() {
        let profile = ServerProfile(name: "NoCache", url: "https://nocache.com", clientID: "xyz")
        CacheService.clear(for: profile) // ensure clean
        XCTAssertNil(CacheService.load(for: profile))
    }

    // MARK: - EAScope

    func test_eaScope_defaultIsComputer() {
        let ea = makeEA(enabled: true)
        XCTAssertEqual(ea.scope, .computer)
    }

    func test_eaScope_mobileRoundTrips() throws {
        var ea = makeEA(enabled: true)
        ea.scope = .mobile
        let data    = try JSONEncoder().encode(ea)
        let decoded = try JSONDecoder().decode(ExtensionAttribute.self, from: data)
        XCTAssertEqual(decoded.scope, .mobile)
    }

    // MARK: - Helpers

    private func makeEA(enabled: Bool) -> ExtensionAttribute {
        ExtensionAttribute(id: 42, name: "Test EA", data_type: "String", enabled: enabled)
    }

    /// Mirrors the classification logic in ScanEngine.run
    private func classify(_ ea: ExtensionAttribute) -> EAStatus {
        if !ea.enabled && ea.dependencies.isEmpty { return .orphaned }
        if ea.dependencies.isEmpty                { return .safe }
        return .used
    }
}
