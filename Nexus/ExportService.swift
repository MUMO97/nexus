// ExportService.swift
// Nexus — Jamf EA Dependency Analyzer
// Copyright © 2025 Murat Kolar. Licensed under GNU GPL v3.
// https://github.com/MUMO97/nexus

import AppKit
import UniformTypeIdentifiers

// MARK: - Export Service
// Pure functions for building CSV, JSON and HTML export content, plus helpers
// for writing to a temp file (open immediately) or via NSSavePanel.
// No AppState dependency — all inputs are passed explicitly.
struct ExportService {

    // MARK: CSV
    static func csv(eas: [ExtensionAttribute]) -> String {
        var out = "ID,Name,Scope,Enabled,Type,Status,Dependencies\n"
        for ea in eas {
            let deps = ea.dependencies
                .map { "\($0.type.rawValue): \($0.name)" }
                .joined(separator: "; ")
            out += "\(ea.id),\"\(ea.name)\",\(ea.scope.rawValue),\(ea.enabled ? "Yes" : "No"),"
            out += "\(ea.data_type ?? "-"),\(ea.status.rawValue),\"\(deps)\"\n"
        }
        return out
    }

    // MARK: JSON
    static func json(eas: [ExtensionAttribute]) -> String? {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted]
        guard let data = try? enc.encode(eas) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: HTML Report
    static func html(eas: [ExtensionAttribute], serverURL: String) -> String {
        let df = DateFormatter(); df.dateStyle = .long; df.timeStyle = .short
        let date   = df.string(from: Date())
        let total  = eas.count
        let safe   = eas.filter { $0.status == .safe }.count
        let used   = eas.filter { $0.status == .used }.count
        let orphan = eas.filter { $0.status == .orphaned }.count

        func esc(_ s: String) -> String {
            s.replacingOccurrences(of: "&", with: "&amp;")
             .replacingOccurrences(of: "<", with: "&lt;")
             .replacingOccurrences(of: ">", with: "&gt;")
        }

        let rows = eas
            .sorted { a, b in
                a.status.sortPriority < b.status.sortPriority ||
                (a.status == b.status && a.id < b.id)
            }
            .map { ea -> String in
                let cls   = ea.status == .safe ? "safe" : ea.status == .used ? "used" : "orphaned"
                let scope = ea.scope == .mobile
                    ? "<span class=\"scope mobile\">Mobile</span>"
                    : "<span class=\"scope computer\">Computer</span>"
                let deps  = ea.dependencies.isEmpty ? "-" :
                    ea.dependencies
                        .map { "\(esc($0.type.rawValue)): \(esc($0.name))" }
                        .joined(separator: "<br>")
                return """
                <tr>
                  <td>\(ea.id)</td>
                  <td>\(esc(ea.name))</td>
                  <td>\(scope)</td>
                  <td>\(ea.enabled ? "Yes" : "No")</td>
                  <td>\(ea.data_type ?? "-")</td>
                  <td><span class="badge \(cls)">\(ea.status.rawValue)</span></td>
                  <td class="deps">\(deps)</td>
                </tr>
                """
            }
            .joined(separator: "\n")

        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="UTF-8">
        <title>Nexus — EA Cleanup Report</title>
        <style>
        *{box-sizing:border-box;margin:0;padding:0}
        body{background:#0D0D12;color:#e0e0e0;font-family:-apple-system,BlinkMacSystemFont,'SF Pro Text',sans-serif;font-size:14px}
        .container{max-width:1200px;margin:0 auto;padding:40px 32px}
        header{margin-bottom:32px}
        header h1{font-size:26px;font-weight:700;color:#fff}
        header .meta{font-size:13px;color:#8B8FA8;margin-top:6px}
        .stats{display:grid;grid-template-columns:repeat(4,1fr);gap:16px;margin-bottom:32px}
        .stat{background:#1A1A24;border:1px solid #2A2A3A;border-radius:12px;padding:20px}
        .stat .lbl{font-size:11px;font-weight:600;text-transform:uppercase;color:#8B8FA8;margin-bottom:8px;letter-spacing:.05em}
        .stat .val{font-size:36px;font-weight:700;color:#fff}
        .stat.safe .val{color:#30D158}.stat.used .val{color:#FF453A}.stat.orphaned .val{color:#FF9F0A}
        table{width:100%;border-collapse:collapse;background:#1A1A24;border-radius:12px;overflow:hidden;border:1px solid #2A2A3A}
        th{background:#12121C;padding:11px 16px;text-align:left;font-size:11px;font-weight:600;text-transform:uppercase;color:#8B8FA8;border-bottom:1px solid #2A2A3A;letter-spacing:.05em}
        td{padding:11px 16px;border-bottom:1px solid #1E1E2C;font-size:13px;color:#e0e0e0;vertical-align:top}
        tr:last-child td{border-bottom:none}
        tr:hover td{background:rgba(255,255,255,.02)}
        .badge{display:inline-flex;align-items:center;padding:3px 10px;border-radius:20px;font-size:11px;font-weight:600}
        .badge.safe{background:rgba(48,209,88,.15);color:#30D158}
        .badge.used{background:rgba(255,69,58,.15);color:#FF453A}
        .badge.orphaned{background:rgba(255,159,10,.15);color:#FF9F0A}
        .deps{font-size:12px;color:#8B8FA8;line-height:1.7}
        .scope{display:inline-flex;align-items:center;padding:2px 8px;border-radius:20px;font-size:10px;font-weight:600}
        .scope.computer{background:rgba(10,132,255,.15);color:#0A84FF}
        .scope.mobile{background:rgba(100,210,255,.15);color:#64D2FF}
        footer{margin-top:32px;text-align:center;font-size:12px;color:#4A4A5A;padding-bottom:16px}
        </style>
        </head>
        <body>
        <div class="container">
          <header>
            <h1>Nexus — EA Cleanup Report</h1>
            <div class="meta">Server: \(esc(serverURL)) &nbsp;·&nbsp; Generated: \(date)</div>
          </header>
          <div class="stats">
            <div class="stat"><div class="lbl">Total EAs</div><div class="val">\(total)</div></div>
            <div class="stat safe"><div class="lbl">Safe to Delete</div><div class="val">\(safe)</div></div>
            <div class="stat used"><div class="lbl">In Use</div><div class="val">\(used)</div></div>
            <div class="stat orphaned"><div class="lbl">Orphaned</div><div class="val">\(orphan)</div></div>
          </div>
          <table>
            <thead><tr><th>ID</th><th>Name</th><th>Scope</th><th>Enabled</th><th>Type</th><th>Status</th><th>Dependencies</th></tr></thead>
            <tbody>
        \(rows)
            </tbody>
          </table>
          <footer>Generated by Nexus &mdash; Jamf EA Dependency Analyzer &mdash; by Murat Kolar</footer>
        </div>
        </body>
        </html>
        """
    }

    // MARK: Delivery helpers
    static func openTemp(_ content: String, filename: String) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? content.write(to: url, atomically: true, encoding: .utf8)
        NSWorkspace.shared.open(url)
    }

    static func saveHTMLWithPanel(_ html: String) {
        let panel = NSSavePanel()
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        panel.nameFieldStringValue = "Nexus_EA_Report_\(df.string(from: Date())).html"
        panel.allowedContentTypes  = [.html]
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? html.write(to: url, atomically: true, encoding: .utf8)
            NSWorkspace.shared.open(url)
        }
    }
}
