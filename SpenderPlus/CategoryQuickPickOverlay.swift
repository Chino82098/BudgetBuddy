import SwiftUI
import SwiftData

struct CategoryQuickPickOverlay: View {
    let categories: [Category]
    let onPick: (Category?) -> Void

    private let cols = [GridItem(.adaptive(minimum: 120), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // "Uncategorized" chip
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    QuickPickChip(
                        title: "Uncategorized",
                        systemImage: "questionmark.circle",   // ← fixed symbol
                        colorHex: "#64748B"
                    ) {
                        onPick(nil)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)
            }

            // Category chips
            ScrollView {
                LazyVGrid(columns: cols, spacing: 8) {
                    ForEach(categories, id: \.persistentModelID) { c in
                        QuickPickChip(
                            title: c.name,
                            systemImage: c.icon,
                            colorHex: c.colorHex
                        ) {
                            onPick(c)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)
        }
        .background {
            let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
            shape
                .fill(.ultraThinMaterial)
                .overlay(
                    shape
                        .strokeBorder(.white.opacity(0.22), lineWidth: 1)
                        .blendMode(.plusLighter)
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)                   // ← fixed shadow
        .frame(maxWidth: 360)
    }
}
