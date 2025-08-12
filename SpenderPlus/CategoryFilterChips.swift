import SwiftUI

struct CategoryFilterChips: View {
    let categories: [Category]
    @Binding var selected: Category?
    @Binding var multiPresented: Bool
    @Binding var multiSelectedNames: Set<String>
    let onSingleChipTap: (Category?) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    title: "All",
                    brand: Color(hex: "#64748B") ?? .gray,
                    isSelected: selected == nil && multiSelectedNames.isEmpty,
                    action: { onSingleChipTap(nil) }
                )

                ForEach(categories) { c in
                    let brand = CategoryStyle.color(for: c.name, modelHex: c.colorHex)
                    FilterChip(
                        title: c.name,
                        brand: brand,
                        isSelected: (selected?.persistentModelID == c.persistentModelID) && multiSelectedNames.isEmpty,
                        action: { onSingleChipTap(c) }
                    )
                }

                // Multi selector
                let multiBrand = Color(hex: "#6B7280") ?? .gray
                FilterChip(
                    title: multiSelectedNames.isEmpty ? "Multi" : "Multi (\(multiSelectedNames.count))",
                    brand: multiBrand,
                    isSelected: !multiSelectedNames.isEmpty,
                    action: {
                        selected = nil      // clear single
                        multiPresented = true
                    }
                )
            }
            .padding(.vertical, 4)
        }
    }
}

private struct FilterChip: View {
    let title: String
    let brand: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.primary) // neutral text
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(.ultraThinMaterial) // translucent fill to match flyout
                .overlay(
                    Capsule()
                        .stroke(brand.opacity(isSelected ? 1.0 : 0.9), lineWidth: isSelected ? 1.8 : 1.3)
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
