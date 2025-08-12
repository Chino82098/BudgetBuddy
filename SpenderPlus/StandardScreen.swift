// StandardScreen.swift
import SwiftUI

struct StandardScreen<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .applyKeyboardUX()   // <- tap/scroll to dismiss, no Done button
    }
}



extension View {
    func standardSheet<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        sheet(isPresented: isPresented) {
            StandardScreen { content() }
        }
    }

    func standardSheet<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        sheet(item: item) { it in
            StandardScreen { content(it) }
        }
    }
}
