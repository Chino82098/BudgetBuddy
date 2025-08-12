import SwiftUI
import SwiftData
import CoreMotion
import UIKit

// Shared layout constants
fileprivate let cardEdgeInset: CGFloat = 20
fileprivate let flyoutBottomOffset: CGFloat = 100

struct ContentView: View {
    @Environment(\.modelContext) private var context

    // Theme toggle (read from the same key BudgetsSheet writes)
    @AppStorage("useDarkMode") private var useDarkMode: Bool = false

    // Queries
    @Query(sort: \Transaction.date, order: .reverse) private var txns: [Transaction]
    @Query private var budgets: [Budget]
    @Query private var categoriesRaw: [Category]

    // Cached categories (sorted)
    @State private var categoriesSorted: [Category] = []

    // UI state
    @State private var showingAdd = false
    @State private var showingBudget = false
    @State private var editingTxn: Transaction?
    @State private var month: Date = Date().startOfMonth()
    @State private var expenseTotal: Double = 0

    // Filters
    @State private var selectedCategory: Category?
    @State private var multiSheetPresented = false
    @State private var multiSelectedNames: Set<String> = []

    // Cached filtered list + total
    @State private var visibleTxns: [Transaction] = []
    @State private var netTotal: Double = 0

    // FAB quick pick overlay
    @State private var showCategoryPicker = false
    @State private var addPresetCategory: Category? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Title + settings
                HStack {
                    Spacer()
                    Text("Budget Buddy")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Button(action: { showingBudget = true }) {
                        Image(systemName: "chart.pie")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Settings")
                }
                .padding(.horizontal)
                .padding(.top, 2)

                // Date picker (month navigation)
                MonthHeader(month: $month)
                    .padding(.top, 4)
                    .padding(.bottom, 6)
                    .foregroundStyle(.primary)

                // Summary card
                BudgetSummaryCard(
                    spent: expenseTotal,
                    budget: overallBudgetAmount(for: month)
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 6) // gap between summary & filter chips

                // Category chips
                CategoryFilterChips(
                    categories: categoriesSorted,
                    selected: $selectedCategory,
                    multiPresented: $multiSheetPresented,
                    multiSelectedNames: $multiSelectedNames,
                    onSingleChipTap: handleSingleChipTap
                )
                .padding(.horizontal)
                .padding(.bottom, 6) // gap between chips & transactions
            
                // Transactions
                TransactionListSection(
                    txns: visibleTxns,
                    onEdit: { editingTxn = $0 },
                    onDuplicate: duplicate(_:),
                    onDelete: deleteTransaction(_:)
                )
            }
            // Hide the nav bar to avoid the jarring bar/transition
            .toolbar(.hidden, for: .navigationBar)

            // Overlays
            .overlay(alignment: .bottomLeading) {
                TotalPillOverlay(title: pillTitle, amount: netTotal)
            }
            .overlay(alignment: .bottomTrailing) {
                FabOverlay { showCategoryPicker = true }
            }
            .overlay(alignment: .bottomTrailing) {
                QuickPickFlyoutOverlay(
                    isPresented: showCategoryPicker,
                    categories: categoriesSorted,
                    onDismiss: { showCategoryPicker = false },
                    onPick: { picked in
                        addPresetCategory = picked
                        showCategoryPicker = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { showingAdd = true }
                    }
                )
            }
            // Sheets
            .sheet(isPresented: $showingAdd) {
                AddTransactionSheet(selectedMonth: month, preselectedCategory: addPresetCategory)
            }
            .sheet(isPresented: $showingBudget) {
                BudgetsSheet(selectedMonth: month)
            }
            .sheet(item: $editingTxn) { txn in
                EditTransactionSheet(txn: txn)
            }
            .sheet(isPresented: $multiSheetPresented) {
                MultiCategoryPickerSheet(
                    allCategories: categoriesSorted,
                    selectedNames: $multiSelectedNames,
                    onDone: { multiSheetPresented = false },
                    onClear: { multiSelectedNames.removeAll() }
                )
                .presentationDetents([.medium, .large])
            }
            // Seed + first compute
            .task {
                print("Categories in store:", categoriesRaw.count, categoriesRaw.map(\.name))
                seedDefaultsIfNeeded()
                ensureDefaultCategoriesLocal()
                syncCategoryColorsWithStyle()
                sortAndCacheCategories()
                recomputeVisible()
            }
            // Recompute only when inputs change
            .onChange(of: categoriesRaw) { sortAndCacheCategories() }
            .onChange(of: txns) { recomputeVisible() }
            .onChange(of: month) { recomputeVisible() }
            .onChange(of: selectedCategory) { recomputeVisible() }
            .onChange(of: multiSelectedNames) { recomputeVisible() }
        }
        // Apply Dark/Light override from Settings
        .preferredColorScheme(useDarkMode ? .dark : .light)
    }

    // MARK: - Derived labels

    private var pillTitle: String {
        if !multiSelectedNames.isEmpty { return "Total — \(multiSelectedNames.count) Selected" }
        if let cat = selectedCategory { return "Total — \(cat.name)" }
        return "Total — All"
    }

    // MARK: - Cache helpers

    private func sortAndCacheCategories() {
        categoriesSorted = categoriesRaw.sorted { a, b in
            if a.sortIndex != b.sortIndex { return a.sortIndex < b.sortIndex }
            return a.name < b.name
        }
    }

    private func recomputeVisible() {
        let start = month.startOfMonth()
        let end = Calendar.current.date(byAdding: .month, value: 1, to: start) ?? start

        var list = txns.filter { $0.date >= start && $0.date < end }

        if !multiSelectedNames.isEmpty {
            list = list.filter { t in
                guard let name = t.category?.name else { return false }
                return multiSelectedNames.contains(name)
            }
        } else if let cat = selectedCategory {
            list = list.filter { $0.category?.persistentModelID == cat.persistentModelID }
        }

        visibleTxns = list
        netTotal = list.reduce(0) { $0 + $1.amount }
        expenseTotal = list.filter { $0.amount < 0 }.reduce(0) { $0 + (-$1.amount) }
    }

    private func overallBudgetAmount(for month: Date) -> Double {
        let start = month.startOfMonth()
        return budgets.first(where: { $0.monthStart == start && $0.category == nil })?.amount ?? 0
    }

    // MARK: - Seeding + Color migration

    private func ensureDefaultCategoriesLocal() {
        guard categoriesRaw.isEmpty else { return }

        // Seed from CategoryStyle so app-wide colors/icons are consistent
        let orderedNames = ["Dining", "Transport", "Bills", "Income", "Entertainment", "Shopping"]
        for (idx, name) in orderedNames.enumerated() {
            let hex = CategoryStyle.desiredColors[name] ?? "#6B7280"
            let icon = CategoryStyle.icon(for: name)
            context.insert(Category(name: name, icon: icon, colorHex: hex, sortIndex: idx))
        }
        try? context.save()
    }

    private func syncCategoryColorsWithStyle() {
        var needsSave = false
        for cat in categoriesRaw {
            if let wantedHex = CategoryStyle.desiredColors[cat.name], cat.colorHex != wantedHex {
                cat.colorHex = wantedHex
                needsSave = true
            }
            // Also keep icons in sync if you changed them
            let wantedIcon = CategoryStyle.icon(for: cat.name)
            if cat.icon != wantedIcon {
                cat.icon = wantedIcon
                needsSave = true
            }
        }
        if needsSave { try? context.save() }
    }

    private func seedDefaultsIfNeeded() {
        let monthStart = Date().startOfMonth()
        if !budgets.contains(where: { $0.monthStart == monthStart && $0.category == nil }) {
            context.insert(Budget(monthStart: monthStart, amount: 2000))
            try? context.save()
        }
    }

    // MARK: - Actions

    private func handleSingleChipTap(_ newSelection: Category?) {
        multiSelectedNames.removeAll()
        selectedCategory = newSelection
    }

    private func duplicate(_ t: Transaction) {
        let copy = Transaction(
            amount: t.amount, date: t.date, note: t.note, category: t.category,
            isRecurring: t.isRecurring, recurFrequency: t.recurFrequency,
            recurInterval: t.recurInterval, recurEndDate: t.recurEndDate, recurGroupID: t.recurGroupID
        )
        context.insert(copy)
        try? context.save()
    }

    private func deleteTransaction(_ t: Transaction) {
        context.delete(t)
        try? context.save()
    }
}

//
// MARK: - Small subviews (kept lightweight)
//

private struct TransactionListSection: View {
    let txns: [Transaction]
    let onEdit: (Transaction) -> Void
    let onDuplicate: (Transaction) -> Void
    let onDelete: (Transaction) -> Void

    // Group by start-of-day and sort sections newest → oldest
    private var grouped: [(day: Date, items: [Transaction])] {
        let groups = Dictionary(grouping: txns) { $0.date.startOfDay }
        return groups
            .map { (key: $0.key, value: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.key > $1.key }
            .map { ($0.key, $0.value) }
    }

    var body: some View {
        List {
            ForEach(grouped, id: \.day) { day, items in
                Section {
                    ForEach(items, id: \.persistentModelID) { t in
                        TransactionRow(t: t)
                            .contentShape(Rectangle())
                            .onTapGesture { onEdit(t) }
                            .contextMenu {
                                Button(action: { onDuplicate(t) }) {
                                    Label("Duplicate", systemImage: "plus.square.on.square")
                                }
                                Button(action: { onEdit(t) }) {
                                    Label("Edit", systemImage: "pencil")
                                }
                                Button(role: .destructive, action: { onDelete(t) }) {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button(action: { onEdit(t) }) {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive, action: { onDelete(t) }) {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button(action: { onDuplicate(t) }) {
                                    Label("Duplicate", systemImage: "plus.square.on.square")
                                }
                                .tint(.teal)
                            }
                    }
                } header: {
                    HStack {
                        Text(Self.headerTitle(for: day))
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                    .textCase(nil)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private static func headerTitle(for day: Date) -> String {
        if Calendar.current.isDateInToday(day) { return "Today" }
        if Calendar.current.isDateInYesterday(day) { return "Yesterday" }
        return DateFormatter.dayHeader.string(from: day)
    }
}

// MARK: - Helpers

private extension Date {
    var startOfDay: Date { Calendar.current.startOfDay(for: self) }
}

private extension DateFormatter {
    static let dayHeader: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .full
        df.timeStyle = .none
        return df
    }()
}

private struct TotalPillOverlay: View {
    let title: String
    let amount: Double

    private var amountColor: Color {
        if amount > 0 { return .green }
        if amount < 0 { return .red }
        return .secondary
    }

    var body: some View {
        // The pill content
        let content = HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption).foregroundStyle(.primary)
                Text(amount.currency).font(.headline).foregroundStyle(amountColor)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }

        if #available(iOS 18.0, *) {
            content
                .glassEffect(
                    .clear.interactive(), // more transparent, reacts to background
                    in: .rect(cornerRadius: 14, style: .continuous)
                )
                .padding(.leading, 24)
                .padding(.bottom, 24)
        } else {
            // Fallback to your previous custom glass
            content
                .background {
                    GlassBackground(
                        shape: RoundedRectangle(cornerRadius: 14, style: .continuous),
                        blurStyle: nil,
                        opacity: 0.62,
                        rimOpacity: 0.32
                    )
                }
                .padding(.leading, 24)
                .padding(.bottom, 24)
        }
    }
}

private struct FabOverlay: View {
    let onTap: () -> Void

    var body: some View {
        let label = Image(systemName: "plus")
            .font(.system(size: 28, weight: .semibold))
            .foregroundStyle(.primary)
            .padding(22)

        Button(action: onTap) {
            if #available(iOS 18.0, *) {
                label
                    .glassEffect(.clear.interactive(), in: .circle)
            } else {
                // Fallback to your previous custom glass
                label
                    .background {
                        GlassBackground(
                            shape: Circle(),
                            blurStyle: nil,
                            opacity: 0.62,
                            rimOpacity: 0.32
                        )
                    }
            }
        }
        .padding(.trailing, 24)
        .padding(.bottom, 24)
    }
}

private struct QuickPickFlyoutOverlay: View {
    let isPresented: Bool
    let categories: [Category]
    let onDismiss: () -> Void
    let onPick: (Category) -> Void

    var body: some View {
        Group {
            if isPresented {
                ZStack(alignment: .bottomTrailing) {
                    Color.black.opacity(0.0001)
                        .ignoresSafeArea()
                        .onTapGesture { onDismiss() }

                    CategoryQuickPickFlyout(categories: categories, onPick: onPick)
                        .padding(.trailing, cardEdgeInset)
                        .padding(.bottom, flyoutBottomOffset)
                        .offset(y: -12)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                        .animation(.easeOut(duration: 0.18), value: isPresented)
                }
            }
        }
    }
}

private struct HeaderArea: View {
    @Binding var month: Date
    let spent: Double
    let budget: Double

    var body: some View {
        VStack(spacing: 8) {
            MonthHeader(month: $month)
            BudgetSummaryCard(spent: spent, budget: budget)
                .padding(.horizontal, 16)
        }
    }
}

// MARK: - Glass utilities (UIKit blur + dynamic highlights)
private struct BlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: style))
        view.isUserInteractionEnabled = false
        return view
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}

private struct GlassBackground<S: Shape>: View {
    @Environment(\.colorScheme) private var scheme
    @StateObject private var tilt = MotionTilt()

    var shape: S
    /// If nil, a scheme-appropriate style is chosen.
    var blurStyle: UIBlurEffect.Style? = nil
    /// Overall translucency of the blurred backdrop (0…1)
    var opacity: Double = 0.60
    /// Strength of the white rim stroke
    var rimOpacity: Double = 0.30

    var body: some View {
        // Resolve a nice, glossy system blur
        let style = blurStyle ?? (scheme == .dark ? .systemThickMaterialDark : .systemThickMaterialLight)

        // Subtle device-tilt for highlight motion
        let tx = CGFloat(max(min(tilt.x, 0.7), -0.7))
        let ty = CGFloat(max(min(tilt.y, 0.7), -0.7))

        ZStack {
            // Layered UIKit blur for stronger distortion (stacked for intensity)
            BlurView(style: style)
                .clipShape(shape)
                .overlay(BlurView(style: style).clipShape(shape).opacity(0.65))
                .opacity(opacity)

            // Gentle dark wash to give depth, keeps background readable
            shape.fill(Color.black.opacity(scheme == .dark ? 0.18 : 0.08))

            // Primary globe-like highlight that slides with tilt
            shape
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.55),
                            Color.white.opacity(0.18),
                            .clear
                        ],
                        center: .init(x: 0.22 + tx * 0.06, y: 0.18 + ty * 0.06),
                        startRadius: 2, endRadius: 140
                    )
                )
                .blendMode(.plusLighter)
                .allowsHitTesting(false)

            // Secondary soft reflection for added depth
            shape
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.22), .clear],
                        center: .init(x: 0.78 + tx * 0.04, y: 0.80 + ty * 0.04),
                        startRadius: 2, endRadius: 170
                    )
                )
                .blendMode(.screen)
                .allowsHitTesting(false)

            // Inner shadow for edge separation (bottom-right)
            shape
                .stroke(Color.black.opacity(scheme == .dark ? 0.22 : 0.18), lineWidth: 6)
                .blur(radius: 10)
                .mask(
                    shape.fill(
                        LinearGradient(
                            colors: [.clear, .black],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                )
                .opacity(0.8)

            // White rim like iOS glass
            shape.stroke(Color.white.opacity(rimOpacity), lineWidth: 1)
        }
        // Soft drop-shadows
        .shadow(color: .black.opacity(scheme == .dark ? 0.28 : 0.18), radius: 14, x: 0, y: 10)
        .shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 1)
        .compositingGroup()
        .saturation(1.04)
        .contrast(1.04)
    }
}

// Simple motion reader for tilt-based parallax
private final class MotionTilt: ObservableObject {
    @Published var x: Double = 0
    @Published var y: Double = 0

    private let manager = CMMotionManager()

    init() {
        guard manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 60.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self, let d = data else { return }
            // Roll (x), Pitch (y) give a nice feel for handheld tilt
            self.x = d.attitude.roll
            self.y = d.attitude.pitch
        }
    }

    deinit { manager.stopDeviceMotionUpdates() }
}
