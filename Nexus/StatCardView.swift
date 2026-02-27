// StatCardView.swift
// Nexus — Jamf EA Dependency Analyzer
// Copyright © 2025 Murat Kolar. Licensed under GNU GPL v3.
// https://github.com/MUMO97/nexus

import SwiftUI

// MARK: - Stat Card (Free)
struct StatCardView: View {
    let title: String
    let value: Int
    let color: Color
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .neonGlow(color: color, radius: 6)
                Spacer()
            }
            Text("\(value)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(AppTheme.mutedText)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.2), lineWidth: 1))
    }
}

// MARK: - Pro Stat Card
// Animated counter + circular progress ring + percentage label.
struct ProStatCardView: View {
    let title: String
    let value: Int
    let total: Int
    let color: Color
    let icon: String

    @State private var animatedValue: Int  = 0
    @State private var animatedRing: Double = 0

    private var percentage: Double {
        total > 0 ? Double(value) / Double(total) : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(color)
                    .neonGlow(color: color, radius: 6)
                Spacer()
                // Circular progress ring
                ZStack {
                    Circle()
                        .stroke(color.opacity(0.12), lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: animatedRing)
                        .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .neonGlow(color: color, radius: 4)
                    Text(total > 0 ? "\(Int(percentage * 100))%" : "—")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundColor(color)
                }
                .frame(width: 32, height: 32)
            }

            Text("\(animatedValue)")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .contentTransition(.numericText())

            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(AppTheme.mutedText)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(color.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            LinearGradient(
                                colors: [color.opacity(0.4), color.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: color.opacity(0.08), radius: 12, x: 0, y: 4)
        .onAppear { animate() }
        .onChange(of: value) { animate() }
    }

    private func animate() {
        withAnimation(.spring(duration: 0.8, bounce: 0.2)) {
            animatedRing = percentage
        }
        withAnimation(.easeOut(duration: 0.6)) {
            animatedValue = value
        }
    }
}
