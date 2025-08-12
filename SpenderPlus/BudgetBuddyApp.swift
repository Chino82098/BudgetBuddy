import SwiftUI
import SwiftData

@main
struct SpenderPlusApp: App {
    var body: some Scene {
        WindowGroup {
            StandardScreen {
                ContentView()
            }
        }
        .modelContainer(for: [
            Category.self,
            Transaction.self,
            Budget.self
        ])
    }
}
