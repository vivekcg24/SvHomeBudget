import SwiftUI
import SwiftData

@main
struct SvHomeBudgetApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // This injects the database environment container into our views
        .modelContainer(for: [ExpenseCategory.self, Expense.self, MonthlyPool.self])
    }
}
