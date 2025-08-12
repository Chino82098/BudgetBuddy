import SwiftUI
import SwiftData

struct SummaryHeader: View {
    @Environment(\.modelContext) private var context
    @Query private var budgets: [Budget]
    @Query private var txns: [Transaction]
    @Binding var month: Date

    var body: some View {
        let monthStart = month.startOfMonth()
        let cal = Calendar.current
        let nextStart = cal.date(byAdding: .month, value: 1, to: monthStart)!

        // This month’s spend
        let monthTxns = txns.filter { $0.date >= monthStart && $0.date < nextStart }
        let spent = monthTxns.filter { $0.amount < 0 }.map { -$0.amount }.reduce(0, +)

        // Budget + progress
        let budget = budgets.first(where: { $0.monthStart == monthStart && $0.category == nil })?.amount ?? 0
        let remaining = max(0, budget - spent)
        let progress = budget > 0 ? min(1, spent / budget) : 0

        return VStack(alignment: .leading, spacing: 10) {
            // Month navigation row
            HStack {
                Button {
                    month = cal.date(byAdding: .month, value: -1, to: month)!.startOfMonth()
                } label: { Image(systemName: "chevron.left") }

                Spacer()

                Text(monthStart, format: .dateTime.year().month())
                    .font(.title2).bold()

                Spacer()

                Button {
                    month = cal.date(byAdding: .month, value: 1, to: month)!.startOfMonth()
                } label: { Image(systemName: "chevron.right") }
            }
            .buttonStyle(.borderless)

            // Budget card (no Income/Net section)
            VStack(alignment: .leading, spacing: 6) {
                Text("Budget: \(budget.currency)")
                ProgressView(value: progress)
                HStack {
                    VStack(alignment: .leading) {
                        Text("Spent").font(.caption).foregroundStyle(.secondary)
                        Text(spent.currency).bold()
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("Remaining").font(.caption).foregroundStyle(.secondary)
                        Text(remaining.currency).bold()
                    }
                }
            }
            .padding()
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .padding(.horizontal)
    }
}
