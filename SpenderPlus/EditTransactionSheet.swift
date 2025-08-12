import SwiftUI
import SwiftData

struct EditTransactionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    // Categories sorted by sortIndex then name
    @Query(sort: [
        SortDescriptor(\Category.sortIndex, order: .forward),
        SortDescriptor(\Category.name, order: .forward)
    ]) private var allCategories: [Category]

    // The txn being edited
    @Bindable var txn: Transaction

    // Form fields
    @State private var amountText: String = ""
    @State private var applyToFuture = true

    // Recurrence editor state
    @State private var freq: TxnRecurrence = .monthly
    @State private var interval: Int = 1
    @State private var endDate: Date? = nil
    @State private var useEndDate: Bool = true

    // Biweekly-friendly UI preset (same as AddTransactionSheet)
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
    @State private var preset: RecurrenceUIPreset = .monthly
    
    // Unified focus for smooth keyboard UX
    private enum Field: Hashable { case amount, note }
    @FocusState private var focusedField: Field?

    // Add this helper:
    private func dismissFocus() {
        focusedField = nil
    }

    // Filter out "Uncategorized" if it exists
    private var categories: [Category] {
        allCategories.filter { $0.name != "Uncategorized" }
    }

    var body: some View {
        NavigationStack {
            Form {
                // Date
                DatePicker("Date", selection: $txn.date, displayedComponents: .date)

                // Category
                Section("Category") {
                    Picker("Category", selection: $txn.category) {
                        ForEach(categories) { c in
                            Text(c.name).tag(Optional<Category>(c))
                        }
                    }
                    .pickerStyle(.menu)
                }

                // Amount
                Section("Amount") {
                    TextField("e.g. -54.23 for expense, 200 for income", text: $amountText)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .amount)
                }

                // Note
                Section("Note") {
                    TextField("Optional note", text: $txn.note)
                        .focused($focusedField, equals: .note)
                        .submitLabel(.done)
                        .onSubmit { focusedField = nil }
                }

                // Recurring controls (if this txn is part of a series)
                if txn.isRecurring {
                    Section("Recurring series") {
                        Toggle("Apply changes to future occurrences", isOn: $applyToFuture)

                        // Preset picker (includes Biweekly)
                        Picker("Repeat", selection: $preset) {
                            ForEach([RecurrenceUIPreset.weekly, .biweekly, .monthly, .yearly, .custom]) { p in
                                Text(p.label).tag(p)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: preset) { _, new in applyPreset(new) }

                        // Advanced only when Custom is chosen
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
                                    get: { endDate ?? defaultEndDate(from: txn.date, freq: freq, interval: interval) },
                                    set: { endDate = $0 }
                                ),
                                displayedComponents: .date
                            )
                        } else {
                            Text("If off, we’ll keep about a year’s worth.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Delete
                Section {
                    Button(role: .destructive) {
                        context.delete(txn)
                        try? context.save()
                        dismiss()
                    } label: {
                        Label("Delete Transaction", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Edit Transaction")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
            }
            .onAppear {
                // Amount text
                amountText = {
                    let nf = NumberFormatter()
                    nf.numberStyle = .decimal
                    nf.maximumFractionDigits = 2
                    nf.minimumFractionDigits = txn.amount == floor(txn.amount) ? 0 : 2
                    return nf.string(from: NSNumber(value: txn.amount)) ?? String(txn.amount)
                }()

                // Prefill recurrence UI from txn
                if txn.isRecurring {
                    freq = txn.recurFrequency ?? .monthly
                    interval = max(1, txn.recurInterval)
                    if let e = txn.recurEndDate {
                        endDate = e; useEndDate = true
                    } else {
                        useEndDate = false
                    }
                    preset = presetFrom(freq: freq, interval: interval)
                }

                // Focus amount on open
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    focusedField = .amount
                }
            }
        }
        // Replace .applyKeyboardUX(...) with:
        .scrollDismissesKeyboard(.interactively)
        .contentShape(Rectangle())
        .onTapGesture { dismissFocus() }
    }

    // MARK: - Save

    private func save() {
        // Set series recurrence fields based on preset
        let newFreq: TxnRecurrence = {
            switch preset {
            case .weekly:   return .weekly
            case .biweekly: return .weekly
            case .monthly:  return .monthly
            case .yearly:   return .yearly
            case .custom:   return freq
            }
        }()

        let newInterval: Int = {
            switch preset {
            case .weekly:   return 1
            case .biweekly: return 2
            case .monthly:  return 1
            case .yearly:   return 1
            case .custom:   return interval
            }
        }()

        // Apply edited values to the current txn
        if let parsed = Double(amountText.replacingOccurrences(of: ",", with: ".")) {
            txn.amount = parsed
        }
        txn.recurFrequency = newFreq
        txn.recurInterval = newInterval
        txn.recurEndDate = useEndDate
            ? (endDate ?? defaultEndDate(from: txn.date, freq: newFreq, interval: newInterval))
            : nil

        // If not recurring or user didn’t opt to cascade, just save this one.
        guard txn.isRecurring, applyToFuture else {
            try? context.save()
            dismiss()
            return
        }

        // Ensure series ID
        if txn.recurGroupID == nil { txn.recurGroupID = UUID() }

        // Fetch FUTURE occurrences (same group, including this one)
        let groupID = txn.recurGroupID
        let startDate = txn.date
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.recurGroupID == groupID && $0.date >= startDate },
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        let future = (try? context.fetch(descriptor)) ?? []

        // Delete future except the edited one; we’ll regenerate
        for t in future where t != txn { context.delete(t) }

        // Regenerate from updated series settings
        if let f = txn.recurFrequency {
            let stop = txn.recurEndDate ?? horizonCap(start: txn.date, freq: f)
            var next = nextDate(from: txn.date, freq: f, every: txn.recurInterval)
            var created = 0
            while next <= stop && created < 120 {
                let copy = Transaction(
                    amount: txn.amount,
                    date: next,
                    note: txn.note,
                    category: txn.category,
                    isRecurring: true,
                    recurFrequency: txn.recurFrequency,
                    recurInterval: txn.recurInterval,
                    recurEndDate: txn.recurEndDate,
                    recurGroupID: txn.recurGroupID
                )
                context.insert(copy)
                created += 1
                next = nextDate(from: next, freq: f, every: txn.recurInterval)
            }
        }

        try? context.save()
        dismiss()
    }

    // MARK: - Recurrence helpers

    private func unitLabel(_ f: TxnRecurrence) -> String {
        switch f { case .weekly: return "week"; case .monthly: return "month"; case .yearly: return "year" }
    }
    private func unitLabelPlural(_ f: TxnRecurrence) -> String {
        switch f { case .weekly: return "weeks"; case .monthly: return "months"; case .yearly: return "years" }
    }

    private func defaultEndDate(from start: Date, freq: TxnRecurrence, interval: Int) -> Date {
        switch freq {
        case .weekly:  return Calendar.current.date(byAdding: .weekOfYear, value: interval * 12, to: start) ?? start
        case .monthly: return Calendar.current.date(byAdding: .month,      value: interval * 12, to: start) ?? start
        case .yearly:  return Calendar.current.date(byAdding: .year,       value: interval * 3,  to: start) ?? start
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
        case .custom:   break
        }
    }
}
