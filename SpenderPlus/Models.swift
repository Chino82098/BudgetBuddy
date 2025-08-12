import Foundation
import SwiftData

// MARK: - Recurrence

enum TxnRecurrence: String, Codable, CaseIterable, Identifiable {
    case weekly, monthly, yearly
    var id: String { rawValue }
    var label: String {
        switch self {
        case .weekly:  return "Weekly"
        case .monthly: return "Monthly"
        case .yearly:  return "Yearly"
        }
    }
}

// MARK: - Category

@Model
final class Category {
    #Index<Category>([\.sortIndex, \.name])

    // MARK: Stored Properties

    @Attribute(.unique) var name: String
    var icon: String
    var colorHex: String
    var sortIndex: Int

    // MARK: Initializers

    init(
        name: String,
        icon: String = "tray",
        colorHex: String = "#4F46E5",
        sortIndex: Int = 0
    ) {
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.sortIndex = sortIndex
    }
}

// MARK: - Transaction

@Model
final class Transaction {
    #Index<Transaction>([\.date, \.isRecurring, \.recurGroupID])

    // MARK: Stored Properties

    var amount: Double
    var date: Date
    var note: String
    var category: Category?

    var isRecurring: Bool
    var recurFrequencyRaw: String?
    var recurInterval: Int
    var recurEndDate: Date?
    var recurGroupID: UUID?

    // MARK: Computed Properties

    var recurFrequency: TxnRecurrence? {
        get { recurFrequencyRaw.flatMap { TxnRecurrence(rawValue: $0) } }
        set { recurFrequencyRaw = newValue?.rawValue }
    }

    // MARK: Initializers

    init(
        amount: Double,
        date: Date = .now,
        note: String = "",
        category: Category? = nil,
        isRecurring: Bool = false,
        recurFrequency: TxnRecurrence? = nil,
        recurInterval: Int = 1,
        recurEndDate: Date? = nil,
        recurGroupID: UUID? = nil
    ) {
        self.amount = amount
        self.date = date
        self.note = note
        self.category = category
        self.isRecurring = isRecurring
        self.recurFrequencyRaw = recurFrequency?.rawValue
        self.recurInterval = max(1, recurInterval)
        self.recurEndDate = recurEndDate
        self.recurGroupID = recurGroupID
    }
}
