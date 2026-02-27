// AppTheme.swift
// Nexus — Jamf EA Dependency Analyzer
// Copyright © 2025 Murat Kolar. Licensed under GNU GPL v3.
// https://github.com/MUMO97/nexus

import SwiftUI

struct AppTheme {
    static let background      = Color(hex: "0D0D12")
    static let surface         = Color(hex: "14141E")
    static let surfaceElevated = Color(hex: "1C1C2E")
    static let accentBlue      = Color(hex: "4F9FFF")
    static let accentPurple    = Color(hex: "A855F7")
    static let safeGreen       = Color(hex: "00FF9C")
    static let dangerRed       = Color(hex: "FF4C6A")
    static let warningOrange   = Color(hex: "FF9500")
    static let mutedText       = Color(hex: "8892A4")
    static let border          = Color.white.opacity(0.07)
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int         & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(AppTheme.border, lineWidth: 1))
    }
}

struct NeonGlow: ViewModifier {
    var color: Color
    var radius: CGFloat = 8
    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.7), radius: radius / 2)
            .shadow(color: color.opacity(0.3), radius: radius)
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 16) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius))
    }
    func neonGlow(color: Color, radius: CGFloat = 8) -> some View {
        modifier(NeonGlow(color: color, radius: radius))
    }
}
