import SwiftUI
import SwiftData

struct QuickAddCategoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var emoji = "🛒"
    @State private var limitString = ""
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Category Description Name", text: $name)
                TextField("Emoji Indicator representation Icon", text: $emoji)
                    .frame(width: 45)
                TextField("Allocated Limit Cost (€)", text: $limitString)
                    .keyboardType(.decimalPad)
            }
            .navigationTitle("New Category")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let limitValue = Double(limitString) ?? 0.0
                        let newCat = ExpenseCategory(name: name, emoji: emoji, monthlyLimit: limitValue)
                        modelContext.insert(newCat)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct QuickAddExpenseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query private var pools: [MonthlyPool]
    
    var categories: [ExpenseCategory]
    var initialDate: Date = Date()
    
    @State private var amountString = ""
    @State private var note = ""
    @State private var expenseDate = Date()
    @State private var selectedCategory: ExpenseCategory?
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Charged Amount (€)", text: $amountString)
                    .keyboardType(.decimalPad)
                TextField("Memo Note/Store Label Description", text: $note)
                
                DatePicker("Transaction Date", selection: $expenseDate, displayedComponents: [.date])
                
                Picker("Target Category Tracker Allocation", selection: $selectedCategory) {
                    Text("Select Target").tag(nil as ExpenseCategory?)
                    ForEach(categories) { cat in
                        Text("\(cat.emoji) \(cat.name)").tag(cat as ExpenseCategory?)
                    }
                }
            }
            .onAppear {
                expenseDate = initialDate
                if selectedCategory == nil {
                    selectedCategory = categories.first
                }
            }
            .navigationTitle("Log Expenditure")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard let amt = Double(amountString), let cat = selectedCategory else { return }
                        let newExpense = Expense(amount: amt, date: expenseDate, note: note, category: cat)
                        modelContext.insert(newExpense)
                        cat.expenses.append(newExpense)
                        
                        reducePoolAmount(by: amt, for: expenseDate)
                        
                        dismiss()
                    }
                    .disabled(Double(amountString) == nil || selectedCategory == nil)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func reducePoolAmount(by amount: Double, for date: Date) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        let monthKey = formatter.string(from: date)
        
        if let existingPool = pools.first(where: { $0.yearMonthString == monthKey }) {
            existingPool.deduct(amount: amount)
        } else {
            let descriptor = FetchDescriptor<MonthlyPool>()
            if let fetchedPools = try? modelContext.fetch(descriptor),
               let match = fetchedPools.first(where: { $0.yearMonthString == monthKey }) {
                match.deduct(amount: amount)
            } else {
                let newPool = MonthlyPool(yearMonthString: monthKey, totalAmount: -amount)
                modelContext.insert(newPool)
            }
        }
        try? modelContext.save()
    }
}
