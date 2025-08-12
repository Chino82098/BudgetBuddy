import SwiftUI


extension Double {
    var currency: String {
        guard self.isFinite else { return "—" }
        return NumberFormatter.currencyCache.string(from: self as NSNumber) ?? String(self)
    }
}

private extension NumberFormatter {
    static let currencyCache: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = .current
        return f
    }()
}

extension Date {
    func startOfMonth(using calendar: Calendar = .current) -> Date {
        let comps = calendar.dateComponents([.year, .month], from: self)
        return calendar.date(from: comps) ?? self
    }
}


extension Color {
    /// Create a Color from common hex string formats.
    /// Supports: RGB (3), RGBA (4), RRGGBB (6), AARRGGBB (8) digits.
    /// Accepts optional prefixes like `#` or `0x`/`0X`.
    init?(hex: String) {
        // Trim whitespace/newlines first
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        // Drop leading '#'
        if hexSanitized.hasPrefix("#") {
            hexSanitized.removeFirst()
        }
        // Drop leading '0x' or '0X'
        if hexSanitized.lowercased().hasPrefix("0x") {
            hexSanitized = String(hexSanitized.dropFirst(2))
        }

        // Only allow hex digits now
        let allowed = CharacterSet(charactersIn: "0123456789aAbBcCdDeEfF")
        if hexSanitized.rangeOfCharacter(from: allowed.inverted) != nil {
            return nil
        }

        var int: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&int) else { return nil }

        let a, r, g, b: UInt64
        switch hexSanitized.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255,
                            (int >> 8) * 17,
                            (int >> 4 & 0xF) * 17,
                            (int & 0xF) * 17)
        case 4: // RGBA (16-bit)
            (a, r, g, b) = ((int & 0xF) * 17,
                            (int >> 12) * 17,
                            (int >> 8 & 0xF) * 17,
                            (int >> 4 & 0xF) * 17)
        case 6: // RRGGBB (24-bit)
            (a, r, g, b) = (255,
                            int >> 16,
                            int >> 8 & 0xFF,
                            int & 0xFF)
        case 8: // AARRGGBB (32-bit)
            (a, r, g, b) = (int >> 24,
                            int >> 16 & 0xFF,
                            int >> 8 & 0xFF,
                            int & 0xFF)
        default:
            return nil
        }

        self.init(.sRGB,
                  red: Double(r) / 255.0,
                  green: Double(g) / 255.0,
                  blue: Double(b) / 255.0,
                  opacity: Double(a) / 255.0)
    }
}


//
//  Helpers.swift
//  SpenderPlus
//
//  Created by Kenneth Yeung on 8/8/25.
//

// MARK: - iOS 26 Liquid Glass convenience modifiers

extension View {
    /// Full-screen/background Liquid Glass using a rectangular shape.
    /// Keeps our usage consistent and avoids repeating the same block everywhere.
    func bbGlassRectBackground(cornerRadius: CGFloat = 0) -> some View {
        background {
            Rectangle()
                .glassEffect(.clear.interactive(), in: .rect(cornerRadius: cornerRadius, style: .continuous))
        }
    }

    /// Card-style Liquid Glass for rounded rectangles (e.g., summary cards, list tiles).
    func bbGlassRoundedCard(_ cornerRadius: CGFloat = 14) -> some View {
        background(
            Color.clear
                .glassEffect(
                    .clear.interactive(),
                    in: .rect(cornerRadius: cornerRadius, style: .continuous)
                )
        )
    }

    /// Circular Liquid Glass background (FABs, icon chips).
    func bbGlassCircleBackground() -> some View {
        background {
            Circle().glassEffect(.clear.interactive(), in: .circle)
        }
    }

    /// Capsule Liquid Glass background (filter chips, tags).
    func bbGlassCapsuleBackground() -> some View {
        background {
            Capsule().glassEffect(.clear.interactive(), in: .capsule)
        }
    }
}

/// A reusable glassy circular icon background with optional soft tint.
struct GlassIconBackground: View {
    var tint: Color? = nil
    var size: CGFloat = 28
    var tintOpacity: Double = 0.14

    var body: some View {
        ZStack {
            Circle().glassEffect(.clear.interactive(), in: .circle)
            if let tint {
                Circle().fill(tint.opacity(tintOpacity))
            }
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
    }
}
