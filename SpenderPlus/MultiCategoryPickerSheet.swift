import SwiftUI
import SwiftData

struct MultiCategoryPickerSheet: View {
    let allCategories: [Category]
    @Binding var selectedNames: Set<String>
    var onDone: () -> Void
    var onClear: () -> Void

    // Search
    @State private var searchText: String = ""

    // Sorted, filtered categories (hide Uncategorized)
    private var categories: [Category] {
        allCategories
            .filter { $0.name != "Uncategorized" }
            .sorted { a, b in
                if a.sortIndex != b.sortIndex { return a.sortIndex < b.sortIndex }
                return a.name < b.name
            }
    }
    private var filtered: [Category] {
        guard !searchText.isEmpty else { return categories }
        return categories.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                // Small header showing count selected
                Section(footer: Text(footerText).font(.footnote).foregroundStyle(.secondary)) {
                    ForEach(filtered, id: \.persistentModelID) { c in
                        MultipleSelectionRow(
                            title: c.name,
                            isSelected: selectedNames.contains(c.name)
                        ) {
                            toggle(c.name)
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.visible)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background {
                Rectangle()
                    .glassEffect(.clear.interactive(), in: .rect(cornerRadius: 0, style: .continuous))
            }
            .navigationTitle("Select Categories")
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search categories"
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear") {
                        selectedNames.removeAll()
                        onClear()
                    }
                    .accessibilityLabel("Clear all selections")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onDone() }
                }
                // Quick select/deselect visible when searching
                ToolbarItem(placement: .primaryAction) {
                    if !filtered.isEmpty {
                        Menu("Select") {
                            Button("Select Visible") { selectVisible() }
                            Button("Deselect Visible") { deselectVisible() }
                        }
                    }
                }
            }
        }
    }

    private var footerText: String {
        let count = selectedNames.count
        return count == 0 ? "None selected" : "\(count) selected"
    }

    private func toggle(_ name: String) {
        if selectedNames.contains(name) {
            selectedNames.remove(name)
        } else {
            selectedNames.insert(name)
        }
    }

    private func selectVisible() {
        for c in filtered { selectedNames.insert(c.name) }
    }

    private func deselectVisible() {
        for c in filtered { selectedNames.remove(c.name) }
    }
}

private struct MultipleSelectionRow: View {
    let title: String
    let isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ZStack {
                    Circle().glassEffect(.clear.interactive(), in: .circle)
                    Circle().fill((isSelected ? Color.accentColor : Color.secondary).opacity(0.14))
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.headline)
                            .foregroundStyle(.primary)
                    }
                }
                .frame(width: 28, height: 28)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(title))
        .accessibilityValue(isSelected ? Text("Selected") : Text("Not selected"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
