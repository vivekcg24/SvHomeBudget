import Foundation
import SwiftData

@Model
final class ExpenseCategory {
    var id: UUID = UUID()
    var name: String
    var emoji: String
    var monthlyLimit: Double
    
    // Relationship: One category has many expenses
    @Relationship(deleteRule: .cascade, inverse: \Expense.category)
    var expenses: [Expense] = []
    
    init(name: String, emoji: String, monthlyLimit: Double) {
        self.name = name
        self.emoji = emoji
        self.monthlyLimit = monthlyLimit
    }
    
    // Helper to calculate total spent in this specific category for the current month
    func totalSpent(for date: Date) -> Double {
        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: date)
        let currentYear = calendar.component(.year, from: date)
        
        return expenses
            .filter {
                calendar.component(.month, from: $0.date) == currentMonth &&
                calendar.component(.year, from: $0.date) == currentYear
            }
            .reduce(0) { $0 + $1.amount }
    }
}

@Model
final class Expense {
    var id: UUID = UUID()
    var amount: Double
    var date: Date
    var note: String
    var category: ExpenseCategory?
    
    init(amount: Double, date: Date, note: String, category: ExpenseCategory? = nil) {
        self.amount = amount
        self.date = date
        self.note = note
        self.category = category
    }
}

@Model
final class MonthlyPool {
    var id: UUID = UUID()
    var yearMonthString: String // Format: "YYYY-MM" (e.g., "2026-10")
    var totalAmount: Double
    
    init(yearMonthString: String, totalAmount: Double) {
        self.yearMonthString = yearMonthString
        self.totalAmount = totalAmount
    }
    
    func deduct(amount: Double) {
        totalAmount -= amount
    }
}
