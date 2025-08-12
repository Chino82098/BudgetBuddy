import Foundation
import SwiftData

@Model
final class Budget {
    #Index<Budget>([\.monthStart, \.category])

    // MARK: Stored Properties
    // Keep an explicit unique id so we can reference and compare reliably.
    // (Avoids using any deprecated/unknown attribute options.)
    @Attribute(.unique) var id: UUID = UUID()

    // Month “bucket” this budget applies to (use startOfMonth() elsewhere when querying)
    var monthStart: Date

    // Amount for this budget. When `category == nil`, this is the overall budget.
    var amount: Double

    // Optional category-specific budget (nil means overall)
    var category: Category?

    // If true, overall budget mirrors this month’s total income (sum of positive txns).
    // You update this in BudgetsSheet; it’s persisted here.
    var syncWithIncome: Bool = false

    // MARK: Initializers
    init(monthStart: Date, amount: Double, category: Category? = nil, syncWithIncome: Bool = false) {
        self.monthStart = monthStart
        self.amount = amount
        self.category = category
        self.syncWithIncome = syncWithIncome
    }
}
