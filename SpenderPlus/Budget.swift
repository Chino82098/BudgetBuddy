import Foundation
import SwiftData

@Model
final class Budget {
    @Attribute(.unique) var id: UUID = UUID()
    var monthStart: Date
    var amount: Double
    var category: Category?  // nil = overall
    var syncWithIncome: Bool = false // Added flag

    init(monthStart: Date, amount: Double, category: Category? = nil) {
        self.monthStart = monthStart
        self.amount = amount
        self.category = category
    }
}
