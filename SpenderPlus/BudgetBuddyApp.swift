import SwiftUI
import SwiftData

@main
struct BudgetBuddyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            Category.self,
            Transaction.self,
            Budget.self
        ])
    }
}
