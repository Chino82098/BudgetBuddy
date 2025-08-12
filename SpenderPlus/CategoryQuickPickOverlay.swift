//
//  CategoryQuickPickOverlay.swift
//  SpenderPlus
//
//  Created by Kenneth Yeung on 8/9/25.
//


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
                    QuickPickChip(title: "Uncategorized",
                                  systemImage: "questionmark.c",
                                  colorHex: "#64748B") {
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
                        QuickPickChip(title: c.name,
                                      systemImage: c.icon,
                                      colorHex: c.colorHex) {
                            onPick(c)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
        }
        .background(.ultraThinMaterial.opacity(0.9))   // slightly opaque, glassy
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(radius: 8, y: 4)
        .frame(maxWidth: 360)
    }
}
