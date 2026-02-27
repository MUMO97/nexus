// NodeGraphView.swift
// Nexus — Jamf EA Dependency Analyzer
// Copyright © 2025 Murat Kolar. Licensed under GNU GPL v3.
// https://github.com/MUMO97/nexus

import SwiftUI
import Foundation

struct NodeGraphView: View {
    let ea: ExtensionAttribute

    var body: some View {
        Canvas { context, size in
            guard !ea.dependencies.isEmpty else { return }
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) * 0.35
            drawEdges(context: context, center: center, radius: radius)
            drawCenterNode(context: context, center: center)
            drawDependencyNodes(context: context, center: center, radius: radius)
        }
    }

    private func nodePosition(index: Int, total: Int, center: CGPoint, radius: CGFloat) -> CGPoint {
        let angle = (2 * .pi / Double(total)) * Double(index) - .pi / 2
        return CGPoint(
            x: center.x + radius * CGFloat(cos(angle)),
            y: center.y + radius * CGFloat(sin(angle))
        )
    }

    private func drawEdges(context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        let total = ea.dependencies.count
        for (i, dep) in ea.dependencies.enumerated() {
            let pos = nodePosition(index: i, total: total, center: center, radius: radius)
            var path = Path()
            path.move(to: center)
            path.addLine(to: pos)
            context.stroke(path, with: .color(dep.type.color.opacity(0.3)), lineWidth: 1.5)
        }
    }

    private func drawCenterNode(context: GraphicsContext, center: CGPoint) {
        let rect = CGRect(x: center.x - 28, y: center.y - 28, width: 56, height: 56)
        context.fill(Path(ellipseIn: rect), with: .color(AppTheme.accentBlue.opacity(0.2)))
        context.stroke(Path(ellipseIn: rect), with: .color(AppTheme.accentBlue), lineWidth: 2)
        context.draw(
            Text("EA").font(.system(size: 12, weight: .bold)).foregroundColor(AppTheme.accentBlue),
            at: center
        )
    }

    private func drawDependencyNodes(context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        let total = ea.dependencies.count
        for (i, dep) in ea.dependencies.enumerated() {
            let pos = nodePosition(index: i, total: total, center: center, radius: radius)
            let rect = CGRect(x: pos.x - 20, y: pos.y - 20, width: 40, height: 40)
            context.fill(Path(ellipseIn: rect), with: .color(dep.type.color.opacity(0.18)))
            context.stroke(Path(ellipseIn: rect), with: .color(dep.type.color), lineWidth: 1.5)
            context.draw(
                Text(String(dep.name.prefix(8))).font(.system(size: 9)).foregroundColor(dep.type.color),
                at: CGPoint(x: pos.x, y: pos.y + 28)
            )
        }
    }
}
