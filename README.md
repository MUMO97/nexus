# Nexus — Jamf EA Dependency Analyzer

> A native macOS app for Jamf Pro administrators to audit, analyze, and safely clean up Extension Attributes.

![macOS 14+](https://img.shields.io/badge/macOS-14.0%2B-blue?logo=apple)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange?logo=swift)
![Version](https://img.shields.io/github/v/release/MUMO97/nexus)
![License](https://img.shields.io/badge/license-GPL%20v3-green)

---

## What is Nexus?

Jamf Pro environments accumulate Extension Attributes over time. Deleting the wrong one breaks Smart Groups, Policies, and Config Profiles — sometimes silently. Nexus solves this by scanning every EA in your environment and mapping exactly where each one is referenced, so you know with confidence what is safe to delete and what is not.

Nexus connects to your Jamf Pro instance via OAuth2 API credentials, scans all Computer and Mobile Device Extension Attributes, and cross-references them against 9 object types in one pass.

---

## Features

### Dependency Scanning
- Scans all Computer and Mobile Device Extension Attributes in a single authenticated pass
- Maps dependencies across **9 object types**: Smart Groups, Advanced Searches, Advanced Search Display Columns, Policies, Configuration Profiles, Restricted Software, Patch Policies, Mobile Smart Groups, Mobile Configuration Profiles
- Uses XPath on Classic API XML responses for accuracy — immune to Jamf's known single-item JSON serialisation bug
- Partial scan resilience: if one object type fails to scan (e.g. insufficient permissions), Nexus returns partial results with a warning rather than failing the entire scan

### Status Classification
Each EA is automatically classified into one of three statuses:
- **Safe to Delete** — not referenced anywhere in the environment
- **In Use** — actively referenced by at least one Jamf object; deleting will break configurations
- **Orphaned** — referenced by objects that no longer exist; technically deletable but worth reviewing

### Dependency Graph
- Interactive node graph visualisation showing exactly which objects reference a selected EA
- Each dependency type is colour-coded for at-a-glance identification

### Script Preview
- View the script body of Script-type EAs directly inside the app without opening Jamf Pro
- Copy script content to clipboard with one click

### Filters and Sorting
- Filter by status: All / Safe to Delete / In Use / Orphaned
- Filter by scope: Computer / Mobile Device
- Filter by data type (String, Integer, Date, etc.)
- Filter disabled EAs only
- Sort by ID, Name, Status, or Dependency count — ascending or descending
- Full-text search across all EA names

### Bulk Operations
- Select individual EAs or use **Select Safe** to automatically select all safe-to-delete EAs
- Bulk delete with a two-step confirmation — Nexus warns loudly if any selected EA is In Use
- Pre-delete export prompt: create a report before deleting for audit trail or Confluence attachment

### Export
- **CSV** — flat spreadsheet of all EAs with status and dependency list
- **JSON** — full structured export for scripting or further processing
- **HTML Report** — formatted cleanup report with summary stats, suitable for documentation or stakeholder review

### Multi-Server Support
- Save and switch between multiple Jamf Pro server profiles
- OAuth2 credentials stored securely in Keychain per profile
- Token expiry tracking with in-app warning and one-click refresh

### Session Management
- Scan results cached per server profile so you can review them without re-scanning every time
- Delete log tracks what was removed during the current session with timestamps
- Open any EA directly in Jamf Pro with one click

---

## Requirements

- macOS 14.0 (Sonoma) or later
- Jamf Pro instance with API access
- Jamf Pro API role with the following read permissions:
  - Computer Extension Attributes
  - Mobile Device Extension Attributes
  - Smart Computer Groups / Smart Mobile Device Groups
  - Advanced Computer Searches / Advanced Mobile Device Searches
  - Computer Policies
  - macOS Configuration Profiles / Mobile Device Configuration Profiles
  - Restricted Software
  - Patch Management

---

## Installation

### Direct Download (Recommended)
1. Go to the [Releases](https://github.com/MUMO97/nexus/releases) page
2. Download the latest `Nexus-vX.X.X.zip`
3. Unzip and move `Nexus.app` to your `/Applications` folder
4. The app is notarized and Developer ID signed — no Gatekeeper workarounds needed

### Homebrew (Coming Soon)
```bash
brew install MUMO97/nexus/nexus
```

---

## Getting Started

1. Launch Nexus
2. Click **Add Server** and enter your Jamf Pro URL, Client ID, and Client Secret
3. Click **Connect** — Nexus will authenticate and begin scanning
4. Review the dependency map in the sidebar and EA list
5. Use filters to focus on **Safe to Delete** EAs
6. Select EAs, export a report, then bulk delete with confidence

---

## Privacy and Security

- Credentials are stored exclusively in the macOS Keychain — never in plain text or UserDefaults
- All API communication is direct between your Mac and your Jamf Pro server — no data passes through any third-party service
- Nexus does not collect telemetry, analytics, or usage data of any kind

---

## Support

- **Mac Admins Slack:** [#nexus-dependency-analyzer](https://macadmins.slack.com/channels/nexus-dependency-analyzer)
- **Issues / Feature Requests:** [GitHub Issues](https://github.com/MUMO97/nexus/issues)

---

## License

Nexus is open source under the [GNU General Public License v3.0](LICENSE).

You are free to view, fork, and contribute to this project. Any derivative works distributed publicly must also be open source under the same license. Commercial redistribution without permission is prohibited.

Copyright © 2025 Murat Kolar. All rights reserved.

---

## Author

Built by **Murat Kolar** — macOS/Jamf administrator and developer.

If Nexus has saved you time cleaning up your Jamf environment, consider starring the repo or sharing it in your admin community.
