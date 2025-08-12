import SwiftUI

struct MonthHeader: View {
    @Binding var month: Date

    var body: some View {
        HStack(spacing: 8) {
            // Previous month
            Button {
                month = Self.prevMonth(from: month)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.black)
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .accessibilityLabel("Previous month")
            .buttonStyle(.plain)

            Spacer(minLength: 8)

            // Centered month/year title
            Text(Self.titleFormatter.string(from: month))
                .font(.headline)
                .foregroundStyle(.primary)
                .accessibilityLabel(Self.accessibilityFormatter.string(from: month))

            Spacer(minLength: 8)

            // Next month
            Button {
                month = Self.nextMonth(from: month)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.black)
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .accessibilityLabel("Next month")
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
        // Smooth snap when month updates
        .animation(.snappy(duration: 0.18), value: month)
    }
}

// MARK: - Helpers
private extension MonthHeader {
    // Always move by whole months and normalize to the first day to avoid drift
    static func prevMonth(from date: Date) -> Date {
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.year, .month], from: date)) ?? date
        return cal.date(byAdding: DateComponents(month: -1), to: start) ?? date
    }

    static func nextMonth(from date: Date) -> Date {
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.year, .month], from: date)) ?? date
        return cal.date(byAdding: DateComponents(month: 1), to: start) ?? date
    }

    static let titleFormatter: DateFormatter = {
        let df = DateFormatter()
        // Localized full month + year (e.g., "August 2025")
        df.setLocalizedDateFormatFromTemplate("yMMMM")
        return df
    }()

    static let accessibilityFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .long
        df.timeStyle = .none
        return df
    }()
}
