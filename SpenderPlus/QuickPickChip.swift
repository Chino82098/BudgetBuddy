//
//  QuickPickChip.swift
//  SpenderPlus
//
//  Created by Kenneth Yeung on 8/9/25.
//


import SwiftUI

struct QuickPickChip: View {
    let title: String
    let systemImage: String
    let colorHex: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                Text(title).lineLimit(1).minimumScaleFactor(0.85)
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background((Color(hex: colorHex) ?? .gray).opacity(0.12))
            .overlay(
                Capsule()
                    .stroke((Color(hex: colorHex) ?? .gray).opacity(0.6), lineWidth: 1)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}