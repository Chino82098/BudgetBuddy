import SwiftUI

struct CategoryQuickPickFlyout: View {
    let categories: [Category]
    let onPick: (Category) -> Void

    // Layout
    private let chipSpacing: CGFloat = 8
    private let chipInsetH: CGFloat = 12
    private let chipInsetV: CGFloat = 9

    var body: some View {
        // Simple vertical wrap-like stack
        VStack(alignment: .trailing, spacing: chipSpacing) {
            ForEach(categories) { c in
                let brand = CategoryStyle.color(for: c.name, modelHex: c.colorHex)
                Button {
                    onPick(c)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: CategoryStyle.icon(for: c.name))
                            .foregroundStyle(.primary) // icon stays neutral
                        Text(c.name)
                            .foregroundStyle(.primary) // text stays neutral
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .font(.subheadline)
                    .padding(.horizontal, chipInsetH)
                    .padding(.vertical, chipInsetV)
                    .background(.ultraThinMaterial) // translucent fill
                    .overlay(
                        Capsule()
                            .stroke(brand.opacity(0.95), lineWidth: 1.6) // vibrant border only
                    )
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}
