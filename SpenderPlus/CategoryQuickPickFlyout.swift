import SwiftUI
import SwiftData


struct CategoryQuickPickFlyout: View {
    let categories: [Category]
    let onPick: (Category) -> Void

    // Layout
    private let chipSpacing: CGFloat = 8
    private let chipInsetH: CGFloat = 12
    private let chipInsetV: CGFloat = 9

    @ViewBuilder
    var body: some View {
        if categories.isEmpty {
            Text("No categories")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .bbGlassRoundedCard(10)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            VStack(alignment: .trailing, spacing: chipSpacing) {
                ForEach(categories, id: \.persistentModelID) { c in
                    CategoryChip(category: c) { onPick($0) }
                }
            }
        }
    }
}

private struct CategoryChip: View {
    let category: Category
    let onTap: (Category) -> Void

    // Keep spacing consistent with parent
    private let chipInsetH: CGFloat = 12
    private let chipInsetV: CGFloat = 9

    var body: some View {
        // Compute color/icon outside the main hierarchy to help the type-checker
        let brand: Color = CategoryStyle.color(for: category.name, modelHex: category.colorHex)
        let icon: String = CategoryStyle.icon(for: category.name)

        Button { onTap(category) } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(.primary)
                    .foregroundStyle(.primary, .secondary)
                Text(category.name)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .font(.subheadline)
            .padding(.horizontal, chipInsetH)
            .padding(.vertical, chipInsetV)
            .frame(minHeight: 44)
            .background(bbGlassCapsuleBackground())
            .overlay(
                Capsule().stroke(brand.opacity(0.95), lineWidth: 1.6)
            )
            .clipShape(Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(category.name)
        .accessibilityAddTraits(.isButton)
    }
}

