import SwiftUI
import SwiftData

struct MultiCategoryPickerSheet: View {
    let allCategories: [Category]
    @Binding var selectedNames: Set<String>
    var onDone: () -> Void
    var onClear: () -> Void

    private var categories: [Category] {
        allCategories
            .filter { $0.name != "Uncategorized" }
            .sorted { a, b in
                if a.sortIndex != b.sortIndex { return a.sortIndex < b.sortIndex }
                return a.name < b.name
            }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(categories, id: \.persistentModelID) { c in
                    MultipleSelectionRow(
                        title: c.name,
                        isSelected: selectedNames.contains(c.name)
                    ) {
                        if selectedNames.contains(c.name) {
                            selectedNames.remove(c.name)
                        } else {
                            selectedNames.insert(c.name)
                        }
                    }
                }
            }
            .navigationTitle("Select Categories")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear") {
                        selectedNames.removeAll()
                        onClear()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onDone() }
                }
            }
        }
    }
}

private struct MultipleSelectionRow: View {
    let title: String
    let isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}
