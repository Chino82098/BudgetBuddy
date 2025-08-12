import SwiftUI
import SwiftData

// Lightweight wrapper to keep the type-checker fast when using Liquid Glass
private struct GlassCard: View {
    let cornerRadius: CGFloat
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .glassEffect(.clear.interactive(), in: .rect(cornerRadius: cornerRadius, style: .continuous))
    }
}

struct BudgetsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    // Theme toggle
    @AppStorage("useDarkMode") private var useDarkMode: Bool = false

    // Data
    @Query private var budgets: [Budget]
    @Query private var categories: [Category]
    @Query(sort: \Transaction.date, order: .reverse) private var txns: [Transaction]

    // Inputs
    let selectedMonth: Date

    // Overall budget UI
    @State private var overallAmountText: String = ""
    @State private var syncWithIncome: Bool = false

    // Reorder sheet
    @State private var showReorder = false

    // Unified focus (mirrors AddTransactionSheet approach)
    private enum Focus: Hashable { case overall, category(PersistentIdentifier) }
    @FocusState private var focus: Focus?
    private func dismissFocus() { focus = nil }

    var body: some View {
        NavigationStack {
            Form {
                overallBudgetSection
                categoryOrderSection
                appearanceSection
                perCategorySection
            }
            .navigationTitle("Settings")
            .scrollContentBackground(.hidden)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            // Reorder sheet
            .sheet(isPresented: $showReorder) {
                ReorderCategoriesSheet(
                    categories: sortedCategories,
                    onApply: { newOrder in
                        for (idx, cat) in newOrder.enumerated() { cat.sortIndex = idx }
                        try? context.save()
                    },
                    onCancel: { }
                )
                .presentationDetents([.medium, .large])
            }
            // Live updates for sync-with-income
            .onChange(of: txns) { _, _ in if syncWithIncome { recomputeSyncedIncomeAndApply() } }
            .onChange(of: selectedMonth) { _, _ in if syncWithIncome { recomputeSyncedIncomeAndApply() } }
        }
        // Match AddTransactionSheet’s keyboard UX exactly
        .scrollDismissesKeyboard(.interactively)
        .contentShape(Rectangle())
        .onTapGesture { dismissFocus() }
        .bbGlassRectBackground()
        // Theme applies immediately to this sheet
        .preferredColorScheme(useDarkMode ? .dark : .light)
    }

    @ViewBuilder private var overallBudgetSection: some View {
        Section("Overall Budget") {
            TextField("Amount", text: $overallAmountText)
                .keyboardType(.decimalPad)
                .disabled(syncWithIncome)
                .focused($focus, equals: .overall)
                .onChange(of: overallAmountText) { _, new in
                    guard !syncWithIncome else { return }
                    applyOverallBudgetChange(new)
                }
                .onAppear { seedOverallFieldsFromModel() }

            Toggle(isOn: $syncWithIncome) {
                Label("Sync with Income", systemImage: "arrow.triangle.2.circlepath")
            }
            .onChange(of: syncWithIncome) { _, nowOn in
                setSyncWithIncome(nowOn)
            }
            .help("When on, the overall budget equals this month’s total income (sum of positive transactions).")
        }
    }

    @ViewBuilder private var categoryOrderSection: some View {
        Section("Category Order") {
            Button { showReorder = true } label: {
                HStack {
                    Image(systemName: "arrow.up.arrow.down")
                    Text("Reorder Categories")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(GlassCard(cornerRadius: 14))
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    @ViewBuilder private var appearanceSection: some View {
        Section {
            Toggle(isOn: $useDarkMode) {
                Label("Dark Mode", systemImage: "moon.fill")
            }
        } footer: {
            Text("Overrides your device appearance. When on, the entire app (including this settings screen) switches to Dark Mode immediately.")
        }
    }

    @ViewBuilder private var perCategorySection: some View {
        Section("Per-Category (Optional)") {
            if sortedCategories.isEmpty {
                Text("No categories yet.").foregroundStyle(.secondary)
            } else {
                ForEach(sortedCategories) { c in
                    perCategoryRow(for: c)
                }
            }
        }
    }

    @ViewBuilder private func perCategoryRow(for c: Category) -> some View {
        HStack {
            Label(c.name, systemImage: c.icon)
            Spacer()
            TextField("0", text: amountBinding(for: c))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 120)
                .focused($focus, equals: .category(c.persistentModelID))
        }
    }

    // MARK: - Derived

    private var monthStart: Date { selectedMonth.startOfMonth() }

    private var sortedCategories: [Category] {
        categories.sorted {
            if $0.sortIndex != $1.sortIndex { return $0.sortIndex < $1.sortIndex }
            return $0.name < $1.name
        }
    }

    // MARK: - Model lookups

    private func existingOverall() -> Budget? {
        budgets.first(where: { $0.monthStart == monthStart && $0.category == nil })
    }

    private func existingFor(_ c: Category) -> Budget? {
        budgets.first(where: { $0.monthStart == monthStart && $0.category?.persistentModelID == c.persistentModelID })
    }

    // MARK: - Overall budget helpers

    private func seedOverallFieldsFromModel() {
        let overall = existingOverall()
        syncWithIncome = overall?.syncWithIncome ?? false
        let startValue: Double = syncWithIncome ? totalIncome(for: selectedMonth) : (overall?.amount ?? 0)
        overallAmountText = numberString(startValue)
        if syncWithIncome {
            setOverallBudgetAmount(to: startValue, markSynced: true)
        }
    }

    private func setSyncWithIncome(_ isOn: Bool) {
        if isOn {
            let income = totalIncome(for: selectedMonth)
            overallAmountText = numberString(income)
            setOverallBudgetAmount(to: income, markSynced: true)
        } else {
            let manual = parseNumber(overallAmountText) ?? 0
            setOverallBudgetAmount(to: manual, markSynced: false)
        }
    }

    private func recomputeSyncedIncomeAndApply() {
        let income = totalIncome(for: selectedMonth)
        overallAmountText = numberString(income)
        setOverallBudgetAmount(to: income, markSynced: true)
    }

    private func setOverallBudgetAmount(to value: Double, markSynced: Bool) {
        if let existing = existingOverall() {
            existing.amount = value
            existing.syncWithIncome = markSynced
        } else {
            let b = Budget(monthStart: monthStart, amount: value, category: nil)
            b.syncWithIncome = markSynced
            context.insert(b)
        }
        try? context.save()
    }

    private func applyOverallBudgetChange(_ newText: String) {
        guard !syncWithIncome, let number = parseNumber(newText) else { return }
        setOverallBudgetAmount(to: number, markSynced: false)
    }

    // MARK: - Per-category changes

    private func applyPerCategoryChange(for c: Category, newText: String) {
        let val = parseNumber(newText) ?? 0
        if let existing = existingFor(c) {
            existing.amount = val
        } else {
            let b = Budget(monthStart: monthStart, amount: val, category: c)
            context.insert(b)
        }
        try? context.save()
    }

    // Small helper to keep the row lightweight for the type-checker
    private func amountBinding(for c: Category) -> Binding<String> {
        Binding<String>(
            get: { numberString(existingFor(c)?.amount ?? 0) },
            set: { applyPerCategoryChange(for: c, newText: $0) }
        )
    }

    // MARK: - Income calc

    private func totalIncome(for month: Date) -> Double {
        let start = month.startOfMonth()
        let end = Calendar.current.date(byAdding: .month, value: 1, to: start) ?? start
        return txns
            .filter { $0.date >= start && $0.date < end }
            .map(\.amount)
            .filter { $0 > 0 }
            .reduce(0, +)
    }

    // MARK: - Number helpers

    private func numberString(_ value: Double) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.maximumFractionDigits = 2
        nf.minimumFractionDigits = value == floor(value) ? 0 : 2
        return nf.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func parseNumber(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }
}

// MARK: - Reorder sheet
private struct ReorderCategoriesSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State var working: [Category]
    let onApply: ([Category]) -> Void
    let onCancel: () -> Void

    init(categories: [Category],
         onApply: @escaping ([Category]) -> Void,
         onCancel: @escaping () -> Void) {
        _working = State(initialValue: categories)
        self.onApply = onApply
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(working) { c in
                    HStack(spacing: 12) {
                        Image(systemName: c.icon)
                            .frame(width: 24)
                            .foregroundStyle(.secondary)
                        Text(c.name)
                        Spacer(minLength: 8)
                        Image(systemName: "line.3.horizontal")
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(GlassCard(cornerRadius: 12))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                .onMove(perform: move)
            }
            .scrollContentBackground(.hidden)
            .bbGlassRectBackground()
            .navigationTitle("Reorder Categories")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel(); dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") { onApply(working); dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    EditButton()
                }
            }
            .toolbarBackground(.automatic, for: .navigationBar)
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
        }
    }

    private func move(from s: IndexSet, to d: Int) {
        working.move(fromOffsets: s, toOffset: d)
    }
}
