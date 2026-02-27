# Nexus — Claude Context File

This file gives Claude full context about the Nexus project so any new session can continue development immediately without re-explaining anything.

---

## What Nexus Is

Nexus is a native macOS SwiftUI app for Jamf Pro administrators. It connects to a Jamf Pro instance via OAuth2 API credentials, scans all Computer and Mobile Device Extension Attributes, and maps every dependency across 9 object types — so admins know exactly which EAs are safe to delete.

**Built by:** Murat Kolar
**GitHub:** https://github.com/MUMO97/nexus
**Support channel:** #nexus-dependency-analyzer on Mac Admins Slack
**Current version:** 1.1.0 (build 2 — signed, notarization pending)
**License:** GNU GPL v3
**Apple Developer Team ID:** JH3UVVVHQ4

---

## Tech Stack

- **Language:** Swift 5.9
- **UI:** SwiftUI (macOS 14.0+)
- **Concurrency:** Swift async/await, TaskGroup
- **Storage:** UserDefaults (scan cache, server profiles, pro flag), Keychain (client secrets, license key)
- **Monetisation:** Gumroad subscription ($4.99/mo) at `celeast.gumroad.com/l/nexus` — `LicenseManager` verifies via Gumroad API on activate + launch
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
    ├── KeychainService.swift   ← Keychain read/write/delete for client secrets + license key
    ├── LicenseManager.swift    ← Pro license state, Gumroad API verification, Keychain storage
    ├── ProUpgradeView.swift    ← Pro upsell sheet: feature list, purchase button, license key entry
    ├── ProUnlockView.swift     ← celebration screen shown after successful activation
    ├── ScanHistoryService.swift← persists scan snapshots per profile, computes delta between scans
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

### LicenseManager
- Singleton: `LicenseManager.shared`
- `@Published isPro: Bool` — gates all Pro UI
- `activate(licenseKey:)` — calls Gumroad API with `increment_uses_count=true`, saves key to Keychain, sets `nexus.pro.active` in UserDefaults
- `verifyOnLaunch()` — reads key from Keychain, re-validates against Gumroad on every launch; calls `deactivate()` only if invalid (network errors keep existing state)
- `deactivate()` — clears Keychain + UserDefaults
- `debugTogglePro()` — **`#if DEBUG` only**, never compiled into Release
- Gumroad product ID: `NHdFRF3ja7LP6JZ-hLLqgg==` (URL-encoded in requests)
- Gumroad URL: `celeast.gumroad.com/l/nexus`
- Free tier limit: `LicenseManager.freeServerLimit = 1`

### Pro Features
- **External Consumer Flag** — `externalConsumerIDs: Set<Int>` in AppState, persisted per server profile in UserDefaults; gold shield badge in EAListView + DetailView toggle
- **EA Script Editing** — inline `TextEditor` in DetailView, Pro-gated; calls `api.updateEAScript()`
- **Scheduled Auto-Scan** — `autoScanInterval: AutoScanInterval` enum in AppState; `restartAutoScanTimer()` uses `Timer.scheduledTimer`; countdown in SidebarView
- **Scan History & Delta** — `ScanHistoryService.save()` after every connect/refresh; `ScanDelta` computed from previous vs current EA IDs; NEW badge on EAListView rows; `ScanDeltaCard` in SidebarView

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
cd "/Users/mkolar/Desktop/Nexus Jamf EA/Nexus"
xcodebuild -scheme Nexus -configuration Release \
  -project "Nexus.xcodeproj" \
  -derivedDataPath /tmp/NexusBuild \
  CODE_SIGN_IDENTITY="Developer ID Application: Murat Kolar (JH3UVVVHQ4)" \
  CODE_SIGN_STYLE=Manual \
  DEVELOPMENT_TEAM=JH3UVVVHQ4 \
  OTHER_CODE_SIGN_FLAGS="--timestamp --options runtime" \
  SDKROOT=macosx build
```

### Re-sign to remove get-task-allow (REQUIRED after every xcodebuild)
Xcode injects `get-task-allow` even in Release builds — must strip it before notarization:
```bash
# Clean entitlements file at /tmp/Nexus-release.entitlements (no get-task-allow):
# com.apple.security.app-sandbox, network.client, files.user-selected.read-write

codesign --force --deep \
  --sign "Developer ID Application: Murat Kolar (JH3UVVVHQ4)" \
  --entitlements /tmp/Nexus-release.entitlements \
  --options runtime \
  --timestamp \
  /tmp/NexusBuild/Build/Products/Release/Nexus.app

# Verify get-task-allow is gone:
codesign -d --entitlements - /tmp/NexusBuild/Build/Products/Release/Nexus.app/Contents/MacOS/Nexus
```

### Zip, Notarize, Staple
```bash
ditto -c -k --keepParent /tmp/NexusBuild/Build/Products/Release/Nexus.app /tmp/Nexus-vX.X.X.zip

xcrun notarytool submit /tmp/Nexus-vX.X.X.zip \
  --team-id JH3UVVVHQ4 \
  --keychain-profile "nexus-notarytool" \
  --wait

xcrun stapler staple /tmp/NexusBuild/Build/Products/Release/Nexus.app
```

### Check notarization status
```bash
xcrun notarytool history --team-id JH3UVVVHQ4 --keychain-profile "nexus-notarytool"
xcrun notarytool info <submission-id> --team-id JH3UVVVHQ4 --keychain-profile "nexus-notarytool"
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
- **get-task-allow entitlement** — Xcode injects this in ALL builds including Release. Always re-sign with `/tmp/Nexus-release.entitlements` after xcodebuild before notarizing. Notarization will fail if this entitlement is present.
- **Notarization first submission** — first-ever submission from a new developer account can take 30min–2hrs. Subsequent ones are 2–5 min.
- **Bundle ID** — Debug build from Xcode uses `com.ea.Nexus`. Old installed app in /Applications uses `com.muratkolar.nexus`. These are separate UserDefaults containers. To reset Pro state for testing: `defaults delete com.ea.Nexus nexus.pro.active`
- **Pro state in Debug** — `debugTogglePro()` is `#if DEBUG` only. To disable Pro for screenshot testing, run: `defaults delete <bundle-id> nexus.pro.active && defaults delete <bundle-id> nexus.license.key` then full Stop → Run in Xcode.
- **fullScreenCover unavailable on macOS** — use `.sheet()` instead
- **Gumroad product ID vs permalink** — API uses `product_id=NHdFRF3ja7LP6JZ-hLLqgg==` (URL-encoded), not `product_permalink`. Sample keys from Gumroad settings do not validate via API — need a real purchase key to test.

---

## What Could Be Added Next

- **PreStage Enrollment scope scanning** (Jamf Pro API v2, different from Classic API)
- **Brew cask distribution** — `brew install --cask nexus-ea` style install
- **Multi-instance comparison** — compare EA usage across two Jamf servers
- **Delta scan** — only re-scan EAs that changed since last run (currently full rescan every time)

---

## How to Continue Development

Just open this project folder in Claude Code and say what feature you want to add. Claude will read this file automatically and have full context. No need to re-explain the architecture, tech stack or patterns.
