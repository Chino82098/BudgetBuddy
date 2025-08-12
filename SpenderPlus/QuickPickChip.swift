import SwiftUI
struct QuickPickChip: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let systemImage: String
    let colorHex: String
    let action: () -> Void

    // Safer color handling + tuned opacities for light/dark
    private var baseColor: Color { Color(hex: colorHex) ?? .accentColor }
    private var bgOpacity: Double { colorScheme == .dark ? 0.18 : 0.12 }
    private var strokeOpacity: Double { colorScheme == .dark ? 0.40 : 0.55 }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .symbolRenderingMode(.hierarchical)
                    .imageScale(.small)
                    .foregroundStyle(baseColor)

                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background {
                Capsule()
                    .glassEffect(.clear.interactive(), in: .capsule)
            }
            .overlay(
                Capsule()
                    .fill(baseColor.opacity(bgOpacity))
            )
            .overlay(
                Capsule()
                    .stroke(baseColor.opacity(strokeOpacity), lineWidth: 1)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(.isButton)
    }
}
