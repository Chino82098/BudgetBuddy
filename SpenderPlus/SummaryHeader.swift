import SwiftUI
import SwiftData

struct SummaryHeader: View {
    @Environment(\.modelContext) private var context
    @Query private var budgets: [Budget]
    @Query private var txns: [Transaction]
    @Binding var month: Date

    var body: some View {
        let cal = Calendar.current
        let monthStart = month.startOfMonth()
        let nextStart = cal.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart

        // This month’s transactions
        let monthTxns = txns.filter { $0.date >= monthStart && $0.date < nextStart }
        let spent = monthTxns
            .filter { $0.amount < 0 }
            .map { -$0.amount }
            .reduce(0, +)

        // Budget + progress
        let budget = budgets.first(where: { $0.monthStart == monthStart && $0.category == nil })?.amount ?? 0
        let remaining = max(0, budget - spent)
        let progress = budget > 0 ? min(max(spent / budget, 0), 1) : 0

        VStack(alignment: .leading, spacing: 12) {
            // Month navigation row
            HStack {
                Button {
                    if let prev = cal.date(byAdding: .month, value: -1, to: month) {
                        month = prev.startOfMonth()
                    }
                } label: {
                    Image(systemName: "chevron.left")
                }
                .accessibilityLabel("Previous month")

                Spacer()

                Text(monthStart, format: .dateTime.year().month())
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)

                Spacer()

                Button {
                    if let next = cal.date(byAdding: .month, value: 1, to: month) {
                        month = next.startOfMonth()
                    }
                } label: {
                    Image(systemName: "chevron.right")
                }
                .accessibilityLabel("Next month")
            }
            .buttonStyle(.borderless)

            // Budget card
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Budget")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(budget.currency)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                }

                ProgressView(value: progress)
                    .tint(.blue)
                    .accessibilityLabel("Budget progress")
                    .accessibilityValue(Text("\(Int((progress * 100).rounded())) percent"))

                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Spent")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(spent.currency)
                            .font(.headline.weight(.semibold))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Remaining")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(remaining.currency)
                            .font(.headline.weight(.semibold))
                    }
                }
            }
            .padding(14)
            .background(
                Color.clear
                    .glassEffect(
                        .clear.interactive(),
                        in: .rect(cornerRadius: 16, style: .continuous)
                    )
            )
        }
        .padding(.horizontal)
    }
}
