// ProUnlockView.swift
// Nexus — Jamf EA Dependency Analyzer
// Copyright © 2025 Murat Kolar. Licensed under GNU GPL v3.
// https://github.com/MUMO97/nexus

import SwiftUI

// MARK: - Pro Unlock Celebration
// Shown exactly once after a user activates Pro.
struct ProUnlockView: View {
    @Environment(\.dismiss) var dismiss
    @State private var scale:      CGFloat = 0.5
    @State private var opacity:    Double  = 0
    @State private var particles:  [ProParticle] = ProParticle.generate(count: 40)
    @State private var burst       = false

    var body: some View {
        ZStack {
            // Dim background
            Color.black.opacity(0.7).ignoresSafeArea()

            // Particles
            ForEach(particles) { p in
                Circle()
                    .fill(p.color)
                    .frame(width: p.size, height: p.size)
                    .offset(
                        x: burst ? p.endX : 0,
                        y: burst ? p.endY : 0
                    )
                    .opacity(burst ? 0 : 1)
                    .animation(
                        .easeOut(duration: Double.random(in: 0.8...1.4))
                        .delay(Double.random(in: 0...0.2)),
                        value: burst
                    )
            }

            // Card
            VStack(spacing: 24) {
                // Icon
                ZStack {
                    Circle()
                        .fill(AppTheme.proGold.opacity(0.15))
                        .frame(width: 80, height: 80)
                        .neonGlow(color: AppTheme.proGold, radius: 24)
                    Image(systemName: "star.fill")
                        .font(.system(size: 32))
                        .foregroundColor(AppTheme.proGold)
                        .neonGlow(color: AppTheme.proGold, radius: 12)
                }

                VStack(spacing: 8) {
                    Text("Welcome to Nexus Pro")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("You now have access to all Pro features.")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.mutedText)
                        .multilineTextAlignment(.center)
                }

                // Pro features unlocked
                VStack(alignment: .leading, spacing: 10) {
                    UnlockRow(icon: "server.rack",              text: "Unlimited Server Profiles")
                    UnlockRow(icon: "clock.arrow.2.circlepath", text: "Scheduled Auto-Scan")
                    UnlockRow(icon: "square.and.pencil",        text: "EA Script Editing")
                    UnlockRow(icon: "link.badge.plus",          text: "External Consumer Protection")
                    UnlockRow(icon: "chart.bar.xaxis",          text: "Scan History & Delta View")
                }
                .padding(16)
                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.proGold.opacity(0.2), lineWidth: 1))

                Button {
                    dismiss()
                } label: {
                    Text("Let's Go")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppTheme.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [AppTheme.proGold, AppTheme.proGoldDim],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .neonGlow(color: AppTheme.proGold, radius: 10)
                }
                .buttonStyle(.plain)
            }
            .padding(28)
            .frame(width: 360)
            .background(AppTheme.background, in: RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [AppTheme.proGold.opacity(0.6), AppTheme.proGold.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.5, bounce: 0.3)) {
                scale   = 1
                opacity = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                burst = true
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Unlock Row
private struct UnlockRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13))
                .foregroundColor(AppTheme.proGold)
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(AppTheme.mutedText)
                .frame(width: 16)
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Particle
struct ProParticle: Identifiable {
    let id   = UUID()
    let color: Color
    let size:  CGFloat
    let endX:  CGFloat
    let endY:  CGFloat

    static func generate(count: Int) -> [ProParticle] {
        let colors: [Color] = [
            AppTheme.proGold, AppTheme.proGold.opacity(0.8),
            AppTheme.accentBlue, .white, AppTheme.safeGreen
        ]
        return (0..<count).map { _ in
            let angle  = Double.random(in: 0..<(2 * .pi))
            let dist   = CGFloat.random(in: 100...260)
            return ProParticle(
                color: colors.randomElement()!,
                size:  CGFloat.random(in: 3...8),
                endX:  cos(angle) * dist,
                endY:  sin(angle) * dist
            )
        }
    }
}
