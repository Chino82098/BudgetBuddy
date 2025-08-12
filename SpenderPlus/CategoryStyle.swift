//
//  CategoryStyle.swift
//  SpenderPlus
//
//  Created by Kenneth Yeung on 8/10/25.
//


import SwiftUI

/// Central place for category icons and brand colors.
/// Use this everywhere so colors stay in sync.
enum CategoryStyle {
    static let desiredColors: [String: String] = [
        "Dining": "#F59E0B",
        "Transport": "#3B82F6", // turquoise
        "Bills": "#EF4444",
        "Income": "#22C55E",
        "Entertainment": "#A855F7",
        "Shopping": "#E879F9"
    ]

    static func icon(for name: String) -> String {
        switch name {
        case "Dining": return "fork.knife"
        case "Transport": return "car"
        case "Bills": return "bolt"
        case "Income": return "banknote"
        case "Entertainment": return "gamecontroller"
        case "Shopping": return "bag"
        default: return "circle"
        }
    }

    /// Prefer the model’s colorHex (it may already be migrated). If missing, fall back to map.
    static func colorHex(for name: String, modelHex: String?) -> String {
        if let hex = modelHex, !hex.isEmpty { return hex }
        return desiredColors[name] ?? "#6B7280" // neutral fallback
    }

    static func color(for name: String, modelHex: String?) -> Color {
        Color(hex: colorHex(for: name, modelHex: modelHex)) ?? .gray
    }
}
