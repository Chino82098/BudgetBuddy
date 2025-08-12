import SwiftUI

struct BudgetSummaryCard: View {
    let spent: Double
    let budget: Double

    private var pct: Double {
        guard budget > 0 else { return 0 }
        return min(max(spent / max(budget, 1), 0), 1)
    }
    private var remaining: Double { budget - spent }

    // Dynamic color for the header budget text
    private var budgetTextColor: Color {
        switch pct {
        case 0..<0.6:  return .green
        case 0.6..<1:  return .orange
        default:       return .red
        }
    }

    // Gradient for the bar
    private var barColor: LinearGradient {
        let c1: Color
        let c2: Color
        switch pct {
        case 0..<0.6:  c1 = .green;  c2 = .green.opacity(0.7)
        case 0.6..<1:  c1 = .orange; c2 = .orange.opacity(0.7)
        default:       c1 = .red;    c2 = .red.opacity(0.7)
        }
        return LinearGradient(colors: [c1, c2], startPoint: .leading, endPoint: .trailing)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Title + Budget (left), % used (right)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Monthly Budget")
                    .font(.headline)
                Text(budgetText)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(budgetTextColor)   // ← dynamic color
                Spacer()
                Text(pctText)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }

            // Progress bar
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.15)).frame(height: 12)
                GeometryReader { geo in
                    Capsule()
                        .fill(barColor)
                        .frame(width: geo.size.width * pct, height: 12)
                        .animation(.easeOut(duration: 0.25), value: pct)
                }
                .frame(height: 12)
            }

            // Bottom row: Spent (left) — Remaining (right)
            HStack(alignment: .firstTextBaseline) {
                Stat(label: "Spent", value: spent, align: .leading)
                Spacer(minLength: 0)
                Stat(label: "Remaining", value: remaining, align: .trailing, emphasizeSign: true)
            }
            .font(.footnote)
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Helpers

    private var pctText: String {
        guard budget > 0 else { return "—" }
        return "\(Int((spent / max(budget, 1)) * 100))%"
    }

    private var budgetText: String {
        budget.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
    }

    private struct Stat: View {
        let label: String
        let value: Double
        var align: HorizontalAlignment = .leading
        var emphasizeSign: Bool = false

        var body: some View {
            VStack(alignment: align, spacing: 2) {
                Text(label).foregroundStyle(.secondary)
                Text(value.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")))
                    .fontWeight(.medium)
                    .foregroundStyle(emphasizeSign && value < 0 ? .red : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: align == .leading ? .leading : .trailing)
        }
    }
}
