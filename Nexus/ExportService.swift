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

    // MARK: HTML Report — Pro
    // Full interactive report with donut chart, search/filter, dependency breakdown.
    // Only generated when LicenseManager.shared.isPro == true.
    static func htmlPro(eas: [ExtensionAttribute], serverURL: String, scanDate: Date?) -> String {
        let df = DateFormatter(); df.dateStyle = .long; df.timeStyle = .short
        let date   = df.string(from: scanDate ?? Date())
        let total  = eas.count
        let safe   = eas.filter { $0.status == .safe   }.count
        let used   = eas.filter { $0.status == .used   }.count
        let orphan = eas.filter { $0.status == .orphaned }.count
        let disabled = eas.filter { !$0.enabled }.count
        let computer = eas.filter { $0.scope == .computer }.count
        let mobile   = eas.filter { $0.scope == .mobile   }.count

        // Dependency type breakdown
        var depCounts: [String: Int] = [:]
        for ea in eas {
            for dep in ea.dependencies {
                depCounts[dep.type.rawValue, default: 0] += 1
            }
        }
        let depSorted = depCounts.sorted { $0.value > $1.value }

        func esc(_ s: String) -> String {
            s.replacingOccurrences(of: "&", with: "&amp;")
             .replacingOccurrences(of: "<", with: "&lt;")
             .replacingOccurrences(of: ">", with: "&gt;")
             .replacingOccurrences(of: "\"", with: "&quot;")
        }

        // Donut chart segments (SVG)
        let cx = 60.0; let cy = 60.0; let r = 44.0; let circ = 2 * Double.pi * r
        func segment(pct: Double, offset: Double, color: String) -> String {
            guard pct > 0 else { return "" }
            let dash = pct * circ
            return """
            <circle cx="\(cx)" cy="\(cy)" r="\(r)" fill="none" stroke="\(color)"
              stroke-width="14" stroke-dasharray="\(String(format:"%.2f",dash)) \(String(format:"%.2f",circ))"
              stroke-dashoffset="\(String(format:"%.2f",-offset*circ))"
              transform="rotate(-90 \(cx) \(cy))"/>
            """
        }
        let pSafe   = total > 0 ? Double(safe)   / Double(total) : 0
        let pUsed   = total > 0 ? Double(used)   / Double(total) : 0
        let pOrphan = total > 0 ? Double(orphan) / Double(total) : 0
        let donut = segment(pct: pSafe,   offset: 0,              color: "#30D158")
                  + segment(pct: pUsed,   offset: pSafe,           color: "#FF453A")
                  + segment(pct: pOrphan, offset: pSafe + pUsed,   color: "#FF9F0A")

        // Dependency breakdown bar items
        let depBar = depSorted.prefix(8).map { item in
            let pct = depCounts.values.max().map { Double(item.value) / Double($0) * 100 } ?? 0
            let color = "#0A84FF" // generic blue; good enough for a text bar
            return """
            <div class="dep-row">
              <div class="dep-label">\(esc(item.key))</div>
              <div class="dep-track"><div class="dep-fill" style="width:\(String(format:"%.1f",pct))%;background:\(color)"></div></div>
              <div class="dep-count">\(item.value)</div>
            </div>
            """
        }.joined()

        // Table rows — JS-searchable data attributes
        let rows = eas
            .sorted { a, b in
                a.status.sortPriority < b.status.sortPriority ||
                (a.status == b.status && a.id < b.id)
            }
            .map { ea -> String in
                let statusCls = ea.status == .safe ? "safe" : ea.status == .used ? "used" : "orphaned"
                let scopeTag  = ea.scope == .mobile
                    ? "<span class=\"scope mobile\">Mobile</span>"
                    : "<span class=\"scope computer\">Computer</span>"
                let enabledTag = ea.enabled
                    ? "<span class=\"enabled-yes\">Yes</span>"
                    : "<span class=\"enabled-no\">No</span>"
                let depHTML: String
                if ea.dependencies.isEmpty {
                    depHTML = "<span class=\"no-deps\">—</span>"
                } else {
                    let items = ea.dependencies.map {
                        "<span class=\"dep-chip\">\(esc($0.type.rawValue))</span> \(esc($0.name))"
                    }.joined(separator: "<br>")
                    depHTML = items
                }
                // data-search attribute for JS filtering
                let searchData = "\(ea.id) \(ea.name) \(ea.status.rawValue) \(ea.scope.rawValue)"
                    .lowercased()
                    .replacingOccurrences(of: "\"", with: "")
                return """
                <tr class="ea-row" data-status="\(statusCls)" data-scope="\(ea.scope == .mobile ? "mobile" : "computer")" data-search="\(esc(searchData))">
                  <td class="id-cell">\(ea.id)</td>
                  <td class="name-cell">\(esc(ea.name))</td>
                  <td>\(scopeTag)</td>
                  <td>\(enabledTag)</td>
                  <td class="type-cell">\(esc(ea.data_type ?? "—"))</td>
                  <td><span class="badge \(statusCls)">\(ea.status.rawValue)</span></td>
                  <td class="deps-cell">\(depHTML)</td>
                </tr>
                """
            }
            .joined(separator: "\n")

        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width,initial-scale=1">
        <title>Nexus Pro — EA Cleanup Report</title>
        <style>
        *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

        :root {
          --bg:       #0B0B12;
          --surface:  #13131E;
          --surface2: #1A1A2A;
          --border:   #252535;
          --text:     #E2E2F0;
          --muted:    #6B6B88;
          --safe:     #30D158;
          --used:     #FF453A;
          --orphan:   #FF9F0A;
          --blue:     #0A84FF;
          --gold:     #F5C842;
        }

        body { background: var(--bg); color: var(--text); font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Helvetica Neue', sans-serif; font-size: 14px; line-height: 1.5; }

        /* ── Top nav ── */
        nav { background: var(--surface); border-bottom: 1px solid var(--border); padding: 0 40px; display: flex; align-items: center; gap: 12px; height: 56px; position: sticky; top: 0; z-index: 100; }
        .nav-logo { font-size: 17px; font-weight: 700; color: #fff; letter-spacing: -0.3px; }
        .nav-pro { font-size: 9px; font-weight: 900; color: var(--gold); background: rgba(245,200,66,.12); border: 1px solid rgba(245,200,66,.3); border-radius: 4px; padding: 2px 6px; letter-spacing: .05em; }
        .nav-sep { flex: 1; }
        .nav-meta { font-size: 12px; color: var(--muted); }
        .nav-dot { color: var(--border); margin: 0 6px; }

        /* ── Page container ── */
        .page { max-width: 1280px; margin: 0 auto; padding: 36px 40px 60px; }

        /* ── Section titles ── */
        .section-title { font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: .08em; color: var(--muted); margin-bottom: 14px; }

        /* ── Summary row ── */
        .summary { display: grid; grid-template-columns: auto 1fr; gap: 28px; margin-bottom: 36px; align-items: start; }
        .donut-wrap { display: flex; align-items: center; gap: 20px; }
        .donut-legend { display: flex; flex-direction: column; gap: 8px; }
        .legend-row { display: flex; align-items: center; gap: 8px; font-size: 13px; }
        .legend-dot { width: 10px; height: 10px; border-radius: 50%; flex-shrink: 0; }
        .legend-val { font-weight: 700; color: #fff; min-width: 28px; text-align: right; font-variant-numeric: tabular-nums; }
        .legend-lbl { color: var(--muted); }

        .stat-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(140px, 1fr)); gap: 12px; }
        .stat { background: var(--surface2); border: 1px solid var(--border); border-radius: 10px; padding: 16px 18px; }
        .stat .lbl { font-size: 10px; font-weight: 600; text-transform: uppercase; letter-spacing: .06em; color: var(--muted); margin-bottom: 6px; }
        .stat .val { font-size: 30px; font-weight: 700; color: #fff; font-variant-numeric: tabular-nums; }
        .stat.safe  .val { color: var(--safe); }
        .stat.used  .val { color: var(--used); }
        .stat.orphan .val { color: var(--orphan); }

        /* ── Dep breakdown ── */
        .dep-breakdown { background: var(--surface); border: 1px solid var(--border); border-radius: 12px; padding: 20px 24px; margin-bottom: 32px; }
        .dep-row { display: grid; grid-template-columns: 180px 1fr 40px; align-items: center; gap: 12px; padding: 5px 0; }
        .dep-label { font-size: 12px; color: var(--text); }
        .dep-track { background: var(--border); border-radius: 4px; height: 6px; overflow: hidden; }
        .dep-fill  { height: 100%; border-radius: 4px; transition: width .4s; }
        .dep-count { font-size: 12px; font-weight: 700; color: #fff; text-align: right; font-variant-numeric: tabular-nums; }
        .no-dep-note { font-size: 13px; color: var(--muted); text-align: center; padding: 12px 0; }

        /* ── Controls ── */
        .controls { display: flex; align-items: center; gap: 10px; margin-bottom: 14px; flex-wrap: wrap; }
        .search-box { flex: 1; min-width: 200px; background: var(--surface2); border: 1px solid var(--border); border-radius: 8px; padding: 7px 12px; color: var(--text); font-size: 13px; outline: none; }
        .search-box:focus { border-color: var(--blue); }
        .search-box::placeholder { color: var(--muted); }
        .filter-btn { background: var(--surface2); border: 1px solid var(--border); border-radius: 8px; padding: 7px 14px; font-size: 12px; color: var(--muted); cursor: pointer; transition: all .15s; }
        .filter-btn:hover, .filter-btn.active { background: rgba(10,132,255,.12); border-color: rgba(10,132,255,.4); color: #fff; }
        .filter-btn.safe-btn.active  { background: rgba(48,209,88,.12);  border-color: rgba(48,209,88,.4);  color: var(--safe);  }
        .filter-btn.used-btn.active  { background: rgba(255,69,58,.12);  border-color: rgba(255,69,58,.4);  color: var(--used);  }
        .filter-btn.orph-btn.active  { background: rgba(255,159,10,.12); border-color: rgba(255,159,10,.4); color: var(--orphan); }
        .row-count { font-size: 12px; color: var(--muted); margin-left: auto; white-space: nowrap; }

        /* ── Table ── */
        .table-wrap { background: var(--surface); border: 1px solid var(--border); border-radius: 12px; overflow: hidden; }
        table { width: 100%; border-collapse: collapse; }
        thead { position: sticky; top: 56px; z-index: 10; }
        th { background: #0F0F1C; padding: 10px 14px; text-align: left; font-size: 10px; font-weight: 700; text-transform: uppercase; letter-spacing: .07em; color: var(--muted); border-bottom: 1px solid var(--border); }
        td { padding: 10px 14px; border-bottom: 1px solid var(--border); font-size: 13px; color: var(--text); vertical-align: top; }
        tr.ea-row:last-child td { border-bottom: none; }
        tr.ea-row:hover td { background: rgba(255,255,255,.025); }
        tr.ea-row.hidden { display: none; }

        .id-cell   { color: var(--muted); font-variant-numeric: tabular-nums; font-size: 12px; width: 54px; }
        .name-cell { font-weight: 500; }
        .type-cell { color: var(--muted); font-size: 12px; }
        .deps-cell { font-size: 12px; color: var(--muted); line-height: 1.8; }
        .no-deps   { color: var(--border); }

        .badge { display: inline-flex; align-items: center; padding: 3px 9px; border-radius: 20px; font-size: 11px; font-weight: 600; }
        .badge.safe    { background: rgba(48,209,88,.15);  color: var(--safe);  }
        .badge.used    { background: rgba(255,69,58,.15);  color: var(--used);  }
        .badge.orphaned{ background: rgba(255,159,10,.15); color: var(--orphan); }

        .scope { display: inline-flex; align-items: center; padding: 2px 8px; border-radius: 20px; font-size: 10px; font-weight: 600; }
        .scope.computer { background: rgba(10,132,255,.15);  color: var(--blue); }
        .scope.mobile   { background: rgba(100,210,255,.15); color: #64D2FF; }

        .enabled-yes { color: var(--safe); font-size: 12px; font-weight: 600; }
        .enabled-no  { color: var(--used); font-size: 12px; font-weight: 600; }

        .dep-chip { display: inline-block; background: rgba(255,255,255,.06); border: 1px solid rgba(255,255,255,.1); border-radius: 4px; padding: 1px 6px; font-size: 10px; font-weight: 600; color: var(--muted); margin-bottom: 2px; }

        /* ── Empty state ── */
        .empty-row td { text-align: center; padding: 32px; color: var(--muted); display: none; }

        /* ── Footer ── */
        footer { margin-top: 40px; display: flex; align-items: center; justify-content: space-between; border-top: 1px solid var(--border); padding-top: 20px; }
        .footer-brand { font-size: 12px; font-weight: 600; color: var(--muted); display: flex; align-items: center; gap: 6px; }
        .footer-gold { color: var(--gold); }
        .footer-right { font-size: 11px; color: var(--border); }

        @media print {
          nav, .controls { display: none !important; }
          .table-wrap { border: none; }
          body { background: #fff; color: #000; }
        }
        </style>
        </head>
        <body>

        <nav>
          <span class="nav-logo">Nexus</span>
          <span class="nav-pro">PRO</span>
          <span class="nav-sep"></span>
          <span class="nav-meta">\(esc(serverURL))<span class="nav-dot">·</span>\(date)</span>
        </nav>

        <div class="page">

          <!-- Summary -->
          <div class="section-title">Summary</div>
          <div class="summary">
            <!-- Donut chart -->
            <div class="donut-wrap">
              <svg width="120" height="120" viewBox="0 0 120 120">
                <circle cx="60" cy="60" r="44" fill="none" stroke="#252535" stroke-width="14"/>
                \(donut)
                <text x="60" y="55" text-anchor="middle" fill="#fff" font-size="20" font-weight="700" font-family="-apple-system,sans-serif">\(total)</text>
                <text x="60" y="70" text-anchor="middle" fill="#6B6B88" font-size="10" font-family="-apple-system,sans-serif">total</text>
              </svg>
              <div class="donut-legend">
                <div class="legend-row"><span class="legend-dot" style="background:var(--safe)"></span><span class="legend-val">\(safe)</span><span class="legend-lbl">Safe to Delete</span></div>
                <div class="legend-row"><span class="legend-dot" style="background:var(--used)"></span><span class="legend-val">\(used)</span><span class="legend-lbl">In Use</span></div>
                <div class="legend-row"><span class="legend-dot" style="background:var(--orphan)"></span><span class="legend-val">\(orphan)</span><span class="legend-lbl">Orphaned</span></div>
              </div>
            </div>

            <!-- Stat cards -->
            <div class="stat-grid">
              <div class="stat safe"><div class="lbl">Safe</div><div class="val">\(safe)</div></div>
              <div class="stat used"><div class="lbl">In Use</div><div class="val">\(used)</div></div>
              <div class="stat orphan"><div class="lbl">Orphaned</div><div class="val">\(orphan)</div></div>
              <div class="stat"><div class="lbl">Disabled</div><div class="val">\(disabled)</div></div>
              <div class="stat"><div class="lbl">Computer</div><div class="val">\(computer)</div></div>
              <div class="stat"><div class="lbl">Mobile</div><div class="val">\(mobile)</div></div>
            </div>
          </div>

          <!-- Dependency breakdown -->
          \(depSorted.isEmpty ? "" : """
          <div class="section-title">Dependency Breakdown</div>
          <div class="dep-breakdown">
            \(depBar)
          </div>
          """)

          <!-- Table controls -->
          <div class="controls">
            <input class="search-box" id="searchBox" type="search" placeholder="Search by name, ID, status…" oninput="applyFilters()">
            <button class="filter-btn active" id="btn-all"    onclick="setFilter('all')">All</button>
            <button class="filter-btn safe-btn" id="btn-safe"   onclick="setFilter('safe')">Safe</button>
            <button class="filter-btn used-btn" id="btn-used"   onclick="setFilter('used')">In Use</button>
            <button class="filter-btn orph-btn" id="btn-orphaned" onclick="setFilter('orphaned')">Orphaned</button>
            <span class="row-count" id="rowCount">\(total) EAs</span>
          </div>

          <!-- Table -->
          <div class="table-wrap">
            <table>
              <thead><tr>
                <th>ID</th><th>Name</th><th>Scope</th><th>Enabled</th><th>Type</th><th>Status</th><th>Dependencies</th>
              </tr></thead>
              <tbody id="tableBody">
        \(rows)
                <tr class="empty-row" id="emptyRow"><td colspan="7">No EAs match this filter.</td></tr>
              </tbody>
            </table>
          </div>

          <footer>
            <div class="footer-brand">
              Generated by <span class="footer-gold">Nexus Pro</span> — Jamf EA Dependency Analyzer · by Murat Kolar
            </div>
            <div class="footer-right">github.com/MUMO97/nexus</div>
          </footer>
        </div>

        <script>
        var currentFilter = 'all';

        function setFilter(f) {
          currentFilter = f;
          ['all','safe','used','orphaned'].forEach(function(id) {
            var btn = document.getElementById('btn-' + id);
            if (btn) btn.classList.toggle('active', id === f);
          });
          applyFilters();
        }

        function applyFilters() {
          var q = document.getElementById('searchBox').value.toLowerCase().trim();
          var rows = document.querySelectorAll('.ea-row');
          var visible = 0;
          rows.forEach(function(row) {
            var statusMatch = currentFilter === 'all' || row.dataset.status === currentFilter;
            var searchMatch = !q || row.dataset.search.indexOf(q) !== -1;
            var show = statusMatch && searchMatch;
            row.classList.toggle('hidden', !show);
            if (show) visible++;
          });
          document.getElementById('rowCount').textContent = visible + ' EA' + (visible !== 1 ? 's' : '');
          var empty = document.getElementById('emptyRow');
          if (empty) empty.style.display = visible === 0 ? 'table-row' : 'none';
        }
        </script>
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
