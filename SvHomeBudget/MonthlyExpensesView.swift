import SwiftUI
import SwiftData

struct MonthlyExpensesView: View {
    @Environment(\.modelContext) private var modelContext
    let monthKey: String
    let monthLabel: String
    
    @Query private var expenses: [Expense]
    
    // Dynamically filter items for the requested calendar cycle layout constraints
    var filteredExpenses: [Expense] {
        expenses.filter { expense in
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM"
            return formatter.string(from: expense.date) == monthKey
        }.sorted { $0.date > $1.date }
    }
    
    var totalMonthCost: Double {
        filteredExpenses.reduce(0) { $0 + $1.amount }
    }
    
    var body: some View {
        List {
            Section(header: Text("Summary Statistics")) {
                HStack {
                    Text("Aggregated Month Spending")
                    Spacer()
                    Text(totalMonthCost, format: .currency(code: "EUR"))
                        .bold()
                        .foregroundColor(.red)
                }
            }
            
            Section(header: Text("Line item History")) {
                if filteredExpenses.isEmpty {
                    Text("No transactions logged inside current target calendar layout month.")
                        .foregroundColor(.secondary)
                        .font(.caption)
                } else {
                    ForEach(filteredExpenses) { item in
                        HStack {
                            Text(item.category?.emoji ?? "💶")
                            VStack(alignment: .leading) {
                                Text(item.note.isEmpty ? (item.category?.name ?? "Expense") : item.note)
                                    .font(.body.bold())
                                Text(item.date, style: .date)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(item.amount, format: .currency(code: "EUR"))
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                    .onDelete(perform: removeLogItem)
                }
            }
        }
        .navigationTitle("\(monthLabel) Expenses")
    }
    
    private func removeLogItem(at offsets: IndexSet) {
        for index in offsets {
            let targetItem = filteredExpenses[index]
            modelContext.delete(targetItem)
        }
    }
}
