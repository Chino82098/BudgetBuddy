import Foundation
import SwiftData

enum TxnRecurrence: String, Codable, CaseIterable, Identifiable {
    case weekly, monthly, yearly
    var id: String { rawValue }
    var label: String {
        switch self {
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        }
    }
}

@Model
final class Category {
    @Attribute(.unique) var name: String
    var icon: String
    var colorHex: String
    var sortIndex: Int            // <-- NEW: user-defined order

    init(name: String,
         icon: String = "tray",
         colorHex: String = "#4F46E5",
         sortIndex: Int = 0) {    // default 0; we'll seed real values
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.sortIndex = sortIndex
    }
}


@Model
final class Transaction {
    var amount: Double
    var date: Date
    var note: String
    var category: Category?

    // Recurring
    var isRecurring: Bool
    var recurFrequencyRaw: String?
    var recurInterval: Int
    var recurEndDate: Date?
    var recurGroupID: UUID?

    var recurFrequency: TxnRecurrence? {
        get { recurFrequencyRaw.flatMap { TxnRecurrence(rawValue: $0) } }
        set { recurFrequencyRaw = newValue?.rawValue }
    }

    init(amount: Double,
         date: Date = .now,
         note: String = "",
         category: Category? = nil,
         isRecurring: Bool = false,
         recurFrequency: TxnRecurrence? = nil,
         recurInterval: Int = 1,
         recurEndDate: Date? = nil,
         recurGroupID: UUID? = nil) {
        self.amount = amount
        self.date = date
        self.note = note
        self.category = category
        self.isRecurring = isRecurring
        self.recurFrequencyRaw = recurFrequency?.rawValue
        self.recurInterval = recurInterval
        self.recurEndDate = recurEndDate
        self.recurGroupID = recurGroupID
    }
}



