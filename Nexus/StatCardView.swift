// StatCardView.swift
// Nexus — Jamf EA Dependency Analyzer
// Copyright © 2025 Murat Kolar. Licensed under GNU GPL v3.
// https://github.com/MUMO97/nexus

import SwiftUI

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
         .overlay(
             RoundedRectangle(cornerRadius: 14)
                 .stroke(color.opacity(0.2), lineWidth: 1)
         )
     }
 }

