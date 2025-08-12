import SwiftUI

// MARK: - BudgetBuddy glass shims (unify iOS 26 vs older)
extension View {

    /// Rounded-rectangle glass container (cards, pills, list rows).
    @ViewBuilder
    func bbGlassContainer(cornerRadius: CGFloat = 12) -> some View {
        self
            .background(
                Color.clear
                    .glassEffect(
                        .clear.interactive(),
                        in: .rect(cornerRadius: cornerRadius, style: .continuous)
                    )
            )
            // Subtle highlight edge to sell the glass look
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 0.75)
            )
    }

    /// Circular glass (good for the floating + button).
    @ViewBuilder
    func bbGlassCircle(padding: CGFloat = 20) -> some View {
        self
            .padding(padding)
            .background {
                Circle().glassEffect(.clear.interactive(), in: .circle)
            }
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.18), lineWidth: 0.75)
            )
    }
}
