import SwiftUI

struct MonthHeader: View {
    @Binding var month: Date

    var body: some View {
        HStack {
            Button(
                action: {
                    month = Calendar.current.date(byAdding: .month, value: -1, to: month) ?? month
                },
                label: { Image(systemName: "chevron.left") }
            )
            Spacer()
            Text(month, style: .date)
                .font(.headline)
            Spacer()
            Button(
                action: {
                    month = Calendar.current.date(byAdding: .month, value: 1, to: month) ?? month
                },
                label: { Image(systemName: "chevron.right") }
            )
        }
        .padding(.horizontal)
    }
}
