# Nexus — Claude Context File

This file gives Claude full context about the Nexus project so any new session can continue development immediately without re-explaining anything.

---

## What Nexus Is

Nexus is a native macOS SwiftUI app for Jamf Pro administrators. It connects to a Jamf Pro instance via OAuth2 API credentials, scans all Computer and Mobile Device Extension Attributes, and maps every dependency across 9 object types — so admins know exactly which EAs are safe to delete.

**Built by:** Murat Kolar
**GitHub:** https://github.com/MUMO97/nexus
**Support channel:** #nexus-dependency-analyzer on Mac Admins Slack
**Current version:** 1.1.0
**License:** GNU GPL v3
**Apple Developer Team ID:** JH3UVVVHQ4

---

## Tech Stack

- **Language:** Swift 5.9
- **UI:** SwiftUI (macOS 14.0+)
- **Concurrency:** Swift async/await, TaskGroup
- **Storage:** UserDefaults (scan cache, server profiles), Keychain (client secrets)
- **Build setting:** `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` — this affects all types, requires `nonisolated` on URLSession delegate methods and struct inits called from background tasks
- **Xcode:** 16+ (uses PBXFileSystemSynchronizedRootGroup — no manual file registration needed, new .swift files are picked up automatically)

---

## Project Structure

```
Nexus/
├── CLAUDE.md                  ← this file
├── Nexus.xcodeproj/
└── Nexus/
    ├── AppState.swift          ← thin coordinator, all @Published UI state
    ├── ScanEngine.swift        ← scan orchestration (fetchEAs + deps, returns ScanResult)
    ├── ExportService.swift     ← pure static CSV/JSON/HTML builders + NSSavePanel
    ├── CacheService.swift      ← UserDefaults scan cache per server profile
    ├── JamfAPIService.swift    ← all Jamf API calls, TLS delegate, dependency scanners
    ├── Models.swift            ← all data models (ExtensionAttribute, DependencyType, etc.)
    ├── EAListView.swift        ← main list, filter chips, action bar, bulk delete
    ├── DetailView.swift        ← right panel: properties, dependency graph, script preview
    ├── SidebarView.swift       ← left panel: stats, status filters, scope/disabled toggles
    ├── LoginView.swift         ← server profile management, connect screen
    ├── NodeGraphView.swift     ← SwiftUI dependency node graph visualisation
    ├── AppTheme.swift          ← all colours, gradients, reusable view modifiers
    ├── KeychainService.swift   ← Keychain read/write/delete for client secrets
    ├── JamfEAAnalyzerApp.swift ← app entry point, menu bar keyboard shortcuts
    └── Info.plist
NexusTests/
└── NexusTests.swift           ← 17 unit tests (status classification, export, cache)
```

---

## Architecture

### AppState (coordinator)
- Owns all `@Published` properties the UI binds to
- Calls `ScanEngine.run()` for scanning, `CacheService` for persistence, `ExportService` for export
- Handles connect/disconnect/refresh/delete
- Does NOT contain scan logic, export logic, or cache logic (those are in their own files)

### ScanEngine
- Pure struct, no AppState dependency
- Takes `(url, token, includeMobile, onProgress)` as inputs
- Returns `ScanResult(eas: [ExtensionAttribute], warning: String?)`
- If dependency scanning partially fails, returns partial results with a warning instead of throwing

### JamfAPIService
- Has a custom `URLSession` with `JamfTLSDelegate` for TLS bypass (needed for instances with hostname mismatch like `jamf.company.com` presenting `*.jamfcloud.com` cert)
- All requests use `session.data(for: req)` — never `URLSession.shared`
- `timeoutInterval: 30` on all requests
- Dependency scanners: `scanSmartGroups`, `scanAdvancedSearches`, `scanPolicies`, `scanConfigProfiles`, `scanRestrictedSoftware`, `scanPatchPolicies` (computer) + `scanMobileSmartGroups`, `scanMobileAdvancedSearches`, `scanMobileConfigProfiles` (mobile)
- All scanners use XPath on XML responses to avoid Jamf's JSON single-item array serialisation bug
- `validate()` treats both 401 AND 403 as `insufficientPermissions` (Jamf Classic API returns 401 for permission errors, not 403)
- `fetchEAScript()` and `fetchMobileEAScript()` read `//input_type/script` XPath from EA XML

### Models
- `ExtensionAttribute` — has `scope: EAScope` (.computer / .mobile), `status: EAStatus`, `dependencies: [DependencyItem]`
- `DependencyType` — 9 cases with icon + color: smartGroup, advancedSearch, advancedSearchDisplay, policy, configProfile, restrictedSoftware, patchPolicy, mobileSmartGroup, mobileAdvancedSearch, mobileConfigProfile
- `EAStatus` — safe, used, orphaned, unknown — has sortPriority, color, icon
- `DependencyItem.init` is marked `nonisolated` (required because SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor)
- `EAScope` is `Codable` (required for cache round-trip)

---

## Key Patterns

### Adding a new dependency scanner
1. Add the new case to `DependencyType` in `Models.swift` with `icon` and `color`
2. Add `scanXxx()` + `fetchXxxDeps()` private methods to `JamfAPIService.swift` following the same pattern as `scanPolicies`
3. Add `async let xxxTask = scanXxx(...)` in `fetchDependencies()` and merge results
4. Update the `onProgress` message in `fetchDependencies`

### Adding a new filter
1. Add `@Published var filterXxx` to `AppState`
2. Add filter logic to `filteredEAs` computed property in `AppState`
3. Add UI control in `SidebarView` or the chip row in `EAListView`
4. Reset in `disconnect()`

### Adding a new export format
1. Add a static method to `ExportService`
2. Add it to the Export menu in `EAListView` and `JamfEAAnalyzerApp` menu bar commands

### nonisolated rule
Any init or method called from a `withTaskGroup` or `async let` context that isn't already `@MainActor` must be marked `nonisolated` if the type gets `@MainActor` inferred from `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.

---

## Build & Release Process

**Apple Developer Team ID:** JH3UVVVHQ4
**Signing identity:** Developer ID Application: Murat Kolar (JH3UVVVHQ4)

### Build signed for release
```bash
xcodebuild -scheme Nexus -configuration Release \
  -project "/path/to/Nexus.xcodeproj" \
  -derivedDataPath /tmp/NexusBuild \
  CODE_SIGN_IDENTITY="Developer ID Application: Murat Kolar (JH3UVVVHQ4)" \
  CODE_SIGN_STYLE=Manual \
  DEVELOPMENT_TEAM=JH3UVVVHQ4 \
  SDKROOT=macosx build
```

### Notarize
```bash
# Submit for notarization (requires app-specific password or API key in Keychain)
xcrun notarytool submit /tmp/Nexus-vX.X.X.zip \
  --team-id JH3UVVVHQ4 \
  --keychain-profile "nexus-notarytool" \
  --wait

# Staple notarization ticket to the app
xcrun stapler staple /tmp/NexusBuild/Build/Products/Release/Nexus.app
```

### Store notarytool credentials (one-time setup)
```bash
xcrun notarytool store-credentials "nexus-notarytool" \
  --team-id JH3UVVVHQ4 \
  --apple-id "YOUR_APPLE_ID_EMAIL"
```

### Zip (preserves macOS metadata)
```bash
ditto -c -k --keepParent /tmp/NexusBuild/Build/Products/Release/Nexus.app /tmp/Nexus-vX.X.X.zip
```

### Create GitHub release
```bash
gh release create vX.X.X /tmp/Nexus-vX.X.X.zip \
  --repo MUMO97/nexus \
  --title "Nexus vX.X.X" \
  --notes "What changed"
```

### Version bump
Xcode → Nexus target → General → Version field. Use semver: 1.0.1 (bug fix), 1.1.0 (feature), 2.0.0 (breaking).

---

## Known Issues / Watch Out For

- **SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor** — any struct init or method called from background tasks needs `nonisolated` or you get "call to main actor-isolated initializer in nonisolated context"
- **Jamf returns 401 (not 403)** for permission errors on Classic API endpoints — `validate()` handles both
- **Duplicate EA names** crash `Dictionary(uniqueKeysWithValues:)` — use `Dictionary(uniquingKeysWith: { first, _ in first })`
- **PBXFileSystemSynchronizedRootGroup** — this is Xcode 16's auto folder sync. New .swift files added to the Nexus/ folder are automatically included. The NexusTests target also uses this.
- **Info.plist excluded from Copy Bundle Resources** via `PBXFileSystemSynchronizedBuildFileExceptionSet` in project.pbxproj

---

## What Could Be Added Next

- **External consumer protection** — EAs used as data holders for external integrations (SIEM tools, Palo Alto Cortex, Tenable, Okta, asset management) show zero internal Jamf dependencies and appear Safe to Delete, but deleting them breaks those integrations silently. Need a way to manually flag EAs as "externally consumed" so they are protected regardless of internal dependency count. Raised by Kyle via LinkedIn — common pattern in environments with Cortex XDR (stores Cortex Device ID in EA to cross-link with Jamf), Splunk/Sentinel SIEM pulls, and vulnerability management platforms correlating on serial/UUID EAs.
- **PreStage Enrollment scope scanning** (Jamf Pro API v2, different from Classic API)
- **EA editing** — view and edit EA scripts directly in the app
- **Scheduled auto-refresh** — rescan on a timer in the background
- **Brew cask distribution** — `brew install --cask nexus-ea` style install
- **Delta scan** — only re-scan EAs that changed since last run
- **Multi-instance comparison** — compare EA usage across two Jamf servers

---

## How to Continue Development

Just open this project folder in Claude Code and say what feature you want to add. Claude will read this file automatically and have full context. No need to re-explain the architecture, tech stack or patterns.
