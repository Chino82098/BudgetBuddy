import SwiftUI

#if canImport(UIKit)
private extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder),
                   to: nil, from: nil, for: nil)
    }
}
#endif

// MARK: - Modifier (no Done button, just dismiss)
struct KeyboardUX: ViewModifier {
    let onBackgroundTap: () -> Void

    func body(content: Content) -> some View {
        content
            // Dismiss by drag/scroll and by tapping outside
            .scrollDismissesKeyboard(.interactively)
            .contentShape(Rectangle())
            .simultaneousGesture(TapGesture().onEnded {
                onBackgroundTap()
                #if canImport(UIKit)
                UIApplication.shared.endEditing()
                #endif
            })
    }
}

// MARK: - Convenience API
extension View {
    /// Tap/scroll dismiss with custom action
    func applyKeyboardUX(
        onBackgroundTap: @escaping () -> Void
    ) -> some View {
        modifier(KeyboardUX(onBackgroundTap: onBackgroundTap))
    }

    /// Tap/scroll dismiss only, default action just ends editing
    func applyKeyboardUX() -> some View {
        modifier(KeyboardUX(
            onBackgroundTap: {
                #if canImport(UIKit)
                UIApplication.shared.endEditing()
                #endif
            }
        ))
    }
}
