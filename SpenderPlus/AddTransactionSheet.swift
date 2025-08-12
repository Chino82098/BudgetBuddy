import SwiftUI
import SwiftData

struct AddTransactionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    // Fetch categories; sort in Swift to reduce type-checker work
    @Query private var categoriesRaw: [Category]
    private var sortedCategories: [Category] {
        categoriesRaw.sorted {
            $0.sortIndex == $1.sortIndex ? ($0.name < $1.name) : ($0.sortIndex < $1.sortIndex)
        }
    }

    // Fields
    @State private var amountText: String = "-"      // expenses default negative
    @State private var date: Date = .now
    @State private var note: String = ""
    @State private var categoryName: String = ""     // non-optional for stable picker binding

    // Recurrence (TxnRecurrence in Models.swift)
    @State private var isRecurring = false
    @State private var freq: TxnRecurrence = .monthly
    @State private var interval: Int = 1
    @State private var endDate: Date? = nil
    @State private var useEndDate: Bool = true
    @State private var preset: RecurrenceUIPreset = .monthly

    // Unified focus (amount + note)
    private enum Field: Hashable { case amount, note }
    @FocusState private var focusedField: Field?
    private func dismissFocus() { focusedField = nil }

    // Inputs
    let selectedMonth: Date
    let preselectedCategory: Category?

    // UI preset (adds Biweekly + Custom)
    private enum RecurrenceUIPreset: String, CaseIterable, Identifiable {
        case weekly, biweekly, monthly, yearly, custom
        var id: String { rawValue }
        var label: String {
            switch self {
            case .weekly:   return "Weekly"
            case .biweekly: return "Biweekly"
            case .monthly:  return "Monthly"
            case .yearly:   return "Yearly"
            case .custom:   return "Custom"
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date", selection: $date, displayedComponents: .date)

                Section("Category") {
                    Picker("Category", selection: $categoryName) {
                        ForEach(sortedCategories) { c in
                            Text(c.name).tag(c.name)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: categoryName) { _, newName in
                        applySignRule(for: newName)
                    }
                }

                Section("Amount") {
                    TextField("e.g. -54.23 for expense, 200 for income", text: $amountText)
                        .textFieldStyle(.plain)
                        .keyboardType(.decimalPad)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .submitLabel(.next)
                        .focused($focusedField, equals: .amount)
                        .onSubmit { focusedField = .note }
                        .modifier(GlassFieldBackground())
                }

                Section("Note") {
                    TextField("Optional note", text: $note)
                        .textFieldStyle(.plain)
                        .textInputAutocapitalization(.sentences)
                        .autocorrectionDisabled(false)
                        .focused($focusedField, equals: .note)
                        .submitLabel(.done)
                        .onSubmit { dismissFocus() }
                        .modifier(GlassFieldBackground())
                }

                // Recurring
                Section("Recurring") {
                    Toggle("Make this a recurring charge", isOn: $isRecurring)

                    if isRecurring {
                        Picker("Repeat", selection: $preset) {
                            ForEach([RecurrenceUIPreset.weekly, .biweekly, .monthly, .yearly, .custom]) { p in
                                Text(p.label).tag(p)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: preset) { _, newValue in
                            applyPreset(newValue)
                        }

                        if preset == .custom {
                            Picker("Frequency", selection: $freq) {
                                ForEach(TxnRecurrence.allCases, id: \.self) { f in
                                    Text(f.label).tag(f)
                                }
                            }
                            Stepper(
                                "Every \(interval) \(interval == 1 ? unitLabel(freq) : unitLabelPlural(freq))",
                                value: $interval, in: 1...52
                            )
                            .onChange(of: interval) { _, _ in preset = presetFrom(freq: freq, interval: interval) }
                            .onChange(of: freq) { _, _ in preset = presetFrom(freq: freq, interval: interval) }
                        }

                        Toggle("End by date", isOn: $useEndDate)
                        if useEndDate {
                            DatePicker(
                                "End Date",
                                selection: Binding<Date>(
                                    get: { endDate ?? defaultEndDate() },
                                    set: { endDate = $0 }
                                ),
                                displayedComponents: .date
                            )
                        } else {
                            Text("Will create up to 12 future occurrences.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("New Transaction")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) }
            }
            .toolbarBackground(.clear, for: .navigationBar)
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
            .animation(.easeInOut(duration: 0.2), value: isRecurring)
            .scrollContentBackground(.hidden)
            .bbGlassRectBackground()
        }
        .onAppear {
            // Ensure we have a valid, selectable category
            syncCategorySelectionIfNeeded()
            // Apply sign rule for starting category
            applySignRule(for: categoryName)
            // Initialize recurrence preset from (freq, interval)
            preset = presetFrom(freq: freq, interval: interval)
            // Auto-focus amount briefly after appear
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                focusedField = .amount
            }
        }
        // Default to Biweekly when user flips the toggle on
        .onChange(of: isRecurring) { old, nowOn in
            guard nowOn == true, old == false else { return }
            preset = .biweekly
            applyPreset(.biweekly)
        }
        // Replace .applyKeyboardUX(...) with:
        .scrollDismissesKeyboard(.interactively)
        .contentShape(Rectangle())
        .onTapGesture { dismissFocus() }
    }

    // Keep selection valid and user-editable
    private func syncCategorySelectionIfNeeded() {
        let validNames = Set(sortedCategories.map(\.name))
        if categoryName.isEmpty || !validNames.contains(categoryName) {
            if let preset = preselectedCategory, validNames.contains(preset.name) {
                categoryName = preset.name
            } else if let first = sortedCategories.first {
                categoryName = first.name
            }
        }
    }

    // MARK: - Save & recurrence

    private func save() {
        guard let amount = Double(amountText.replacingOccurrences(of: ",", with: ".")) else { return }
        let chosenCategory = sortedCategories.first(where: { $0.name == categoryName })
        let seriesID = isRecurring ? UUID() : nil

        let base = Transaction(
            amount: amount,
            date: date,
            note: note,
            category: chosenCategory,
            isRecurring: isRecurring,
            recurFrequency: isRecurring ? freq : nil,
            recurInterval: isRecurring ? interval : 1,
            recurEndDate: isRecurring ? (useEndDate ? (endDate ?? defaultEndDate()) : nil) : nil,
            recurGroupID: seriesID
        )
        context.insert(base)

        if isRecurring, let freqRule = base.recurFrequency {
            let stopDate = base.recurEndDate ?? horizonCap(start: base.date, freq: freqRule)
            var next = nextDate(from: base.date, freq: freqRule, every: base.recurInterval)
            var created = 0
            while next <= stopDate && created < 120 {
                let copy = Transaction(
                    amount: base.amount,
                    date: next,
                    note: base.note,
                    category: base.category,
                    isRecurring: true,
                    recurFrequency: base.recurFrequency,
                    recurInterval: base.recurInterval,
                    recurEndDate: base.recurEndDate,
                    recurGroupID: seriesID
                )
                context.insert(copy)
                created += 1
                next = nextDate(from: next, freq: freqRule, every: base.recurInterval)
            }
        }

        try? context.save()
        dismiss()
    }

    // MARK: - Amount sign rule

    /// If category is "Income" → force positive. Else → force negative (unless zero).
    private func applySignRule(for name: String) {
        let isIncome = (name == "Income")
        var t = amountText.trimmingCharacters(in: .whitespaces)

        if t.hasPrefix("+") { t.removeFirst() }

        if t.isEmpty || t == "-" {
            amountText = isIncome ? "" : "-"
            return
        }

        let raw = t.hasPrefix("-") ? String(t.dropFirst()) : t
        let val = Double(raw.replacingOccurrences(of: ",", with: ".")) ?? 0

        if isIncome {
            amountText = String(raw)
        } else {
            if val == 0 {
                amountText = "0"
            } else {
                amountText = t.hasPrefix("-") ? t : "-" + raw
            }
        }
    }

    // MARK: - Recurrence helpers

    private func unitLabel(_ f: TxnRecurrence) -> String {
        switch f {
        case .weekly:  return "week"
        case .monthly: return "month"
        case .yearly:  return "year"
        }
    }
    private func unitLabelPlural(_ f: TxnRecurrence) -> String {
        switch f {
        case .weekly:  return "weeks"
        case .monthly: return "months"
        case .yearly:  return "years"
        }
    }

    private func defaultEndDate() -> Date {
        switch freq {
        case .weekly:  return Calendar.current.date(byAdding: .weekOfYear, value: interval * 12, to: date) ?? date
        case .monthly: return Calendar.current.date(byAdding: .month,      value: interval * 12, to: date) ?? date
        case .yearly:  return Calendar.current.date(byAdding: .year,       value: interval * 3,  to: date) ?? date
        }
    }

    private func horizonCap(start: Date, freq: TxnRecurrence) -> Date {
        switch freq {
        case .weekly:  return Calendar.current.date(byAdding: .weekOfYear, value: 52, to: start) ?? start
        case .monthly: return Calendar.current.date(byAdding: .month,      value: 12, to: start) ?? start
        case .yearly:  return Calendar.current.date(byAdding: .year,       value: 3,  to: start) ?? start
        }
    }

    private func nextDate(from d: Date, freq: TxnRecurrence, every: Int) -> Date {
        let cal = Calendar.current
        switch freq {
        case .weekly:  return cal.date(byAdding: .weekOfYear, value: every, to: d) ?? d
        case .monthly: return cal.date(byAdding: .month,      value: every, to: d) ?? d
        case .yearly:  return cal.date(byAdding: .year,       value: every, to: d) ?? d
        }
    }

    private func presetFrom(freq: TxnRecurrence, interval: Int) -> RecurrenceUIPreset {
        switch (freq, interval) {
        case (.weekly, 1):  return .weekly
        case (.weekly, 2):  return .biweekly
        case (.monthly, 1): return .monthly
        case (.yearly, 1):  return .yearly
        default:            return .custom
        }
    }

    private func applyPreset(_ p: RecurrenceUIPreset) {
        switch p {
        case .weekly:   freq = .weekly;  interval = 1
        case .biweekly: freq = .weekly;  interval = 2
        case .monthly:  freq = .monthly; interval = 1
        case .yearly:   freq = .yearly;  interval = 1
        case .custom:   break // leave as-is; user edits below
        }
    }
}

// MARK: - Modern glass background for inputs (iOS 26 look)
private struct GlassFieldBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                Color.clear
                    .glassEffect(.clear.interactive(), in: .rect(cornerRadius: 14, style: .continuous))
                    // Subtle "liquid glass" sheen (kept from previous design)
                    .overlay(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                .white.opacity(0.40),
                                .white.opacity(0.12),
                                .white.opacity(0.04),
                                .white.opacity(0.28),
                                .white.opacity(0.40)
                            ]),
                            center: .center
                        )
                        .blendMode(.plusLighter)
                        .opacity(0.22)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    )
                    // Soft inner highlight ring
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(.white.opacity(0.38), lineWidth: 0.75)
                            .blendMode(.plusLighter)
                    )
            )
            // Gentle drop shadow to lift off the form
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 6)
    }
}
