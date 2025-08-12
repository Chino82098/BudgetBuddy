//
//  CategoryStyle.swift
//  SpenderPlus
//
//  Central source of truth for category icons and brand colors.
//  Keep this in sync with seeding/migrations so UI stays consistent.
//

import SwiftUI

enum CategoryStyle {
    // MARK: - Constants

    /// Canonical order used for first‑run seeding and any UI that wants a stable list.
    static let orderedDefaultNames: [String] = [
        "Dining",
        "Transport",
        "Bills",
        "Income",
        "Entertainment",
        "Shopping"
    ]

    /// Brand colors for each category (hex string, #RRGGBB).
    /// NOTE: "Transport" comment corrected to reflect the actual color (blue).
    static let desiredColors: [String: String] = [
        "Dining":        "#F59E0B",
        "Transport":     "#3B82F6", // blue
        "Bills":         "#EF4444",
        "Income":        "#22C55E",
        "Entertainment": "#A855F7",
        "Shopping":      "#E879F9"
    ]

    // MARK: - Icon Lookup

    /// Returns an SF Symbol name for a given category.
    static func icon(for name: String) -> String {
        switch name {
        case "Dining":        return "fork.knife"
        case "Transport":     return "car"
        case "Bills":         return "bolt"
        case "Income":        return "banknote"
        case "Entertainment": return "gamecontroller"
        case "Shopping":      return "bag"
        default:              return "circle"
        }
    }

    // MARK: - Color Helpers

    /// Prefer the model’s colorHex (it may already be migrated). If missing, fall back to map.
    static func colorHex(for name: String, modelHex: String?) -> String {
        if let hex = modelHex, !hex.isEmpty { return hex }
        return desiredColors[name] ?? "#6B7280" // neutral fallback
    }

    /// Convenience: SwiftUI Color from category name and/or stored hex.
    static func color(for name: String, modelHex: String?) -> Color {
        Color(hex: colorHex(for: name, modelHex: modelHex)) ?? .gray
    }

    // MARK: - Seeding

    /// Convenience for seeding: tuples of (name, icon, colorHex) in canonical order.
    static func seedTuples() -> [(name: String, icon: String, colorHex: String)] {
        orderedDefaultNames.map { n in (n, icon(for: n), desiredColors[n] ?? "#6B7280") }
    }
}
