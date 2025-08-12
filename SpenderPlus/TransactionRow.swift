import SwiftUI

struct TransactionRow: View {
    let t: Transaction

    var body: some View {
        HStack(spacing: 12) {
            // Icon bubble
            Circle()
                .fill((Color(hex: t.category?.colorHex ?? "#64748B") ?? .gray).opacity(0.2))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: t.category?.icon ?? "tray")
                        .font(.system(size: 16, weight: .semibold))
                )

            // Texts
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(t.category?.name ?? "Uncategorized")
                        .font(.headline)

                    // NEW: recurring hint
                    if t.isRecurring {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .imageScale(.small)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Recurring")
                    }
                }

                if !t.note.isEmpty {
                    Text(t.note)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Amount + date
            VStack(alignment: .trailing, spacing: 2) {
                Text(t.amount.currency)
                    .font(.headline)
                    .foregroundStyle(t.amount < 0 ? .red : .green)
                Text(t.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
        }
        .padding(.vertical, 4)
    }
}
