import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    
    // Fetch data reactively from SwiftData local database
    @Query var categories: [ExpenseCategory]
    @Query var pools: [MonthlyPool]
    @Query var allExpenses: [Expense]
    
    // State management for sheets and adjustments
    @State private var showQuickAddCategory = false
    @State private var showAddExpenseSheet = false
    @State private var showEditPoolAlert = false
    @State private var poolInputString = ""
    
    // Date tracking properties - now stateful to support month navigation (Approach A)
    @State private var selectedDate: Date = Date()
    
    private var isCurrentMonth: Bool {
        Calendar.current.isDate(selectedDate, equalTo: Date(), toGranularity: .month)
    }
    
    private var currentMonthString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: selectedDate)
    }
    
    private var currentYearMonthKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: selectedDate)
    }
    
    // Find or fallback total budget injected for this month
    private var currentMonthlyPool: MonthlyPool? {
        pools.first { $0.yearMonthString == currentYearMonthKey }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // --- 1. Dynamic Header Area with Month Stepper (Approach A) ---
                VStack(spacing: 8) {
                    HStack(alignment: .center) {
                        // Previous Month Button
                        Button(action: { changeMonth(by: -1) }) {
                            Image(systemName: "chevron.left.circle.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Previous month")
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(currentMonthString)
                                .font(.title3.bold())
                                .foregroundColor(.primary)
                            
                            HStack(spacing: 4) {
                                Text(isCurrentMonth ? "Current Cycle" : "Historical Cycle")
                                    .font(.caption2)
                                    .foregroundColor(isCurrentMonth ? .secondary : .orange)
                                
                                if !isCurrentMonth {
                                    Button(action: resetToCurrentMonth) {
                                        Text("• Today")
                                            .font(.caption2.bold())
                                            .foregroundColor(.blue)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        
                        // Next Month Button
                        Button(action: { changeMonth(by: 1) }) {
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.title2)
                                .foregroundColor(isCurrentMonth ? .gray.opacity(0.5) : .blue)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Next month")
                        // 🔴 Disables interaction completely when on the current month
                        .disabled(isCurrentMonth)
                        
                        Spacer()
                        
                        // Added Pool Display Trigger Button
                        Button(action: {
                            poolInputString = String(format: "%.2f", currentMonthlyPool?.totalAmount ?? 0.0)
                            showEditPoolAlert = true
                        }) {
                            VStack(alignment: .trailing) {
                                Text("Added Pool")
                                    .font(.caption2)
                                    .textCase(.uppercase)
                                    .foregroundColor(.secondary)
                                Text(currentMonthlyPool?.totalAmount ?? 0.0, format: .currency(code: "EUR"))
                                    .font(.headline.bold())
                                    .foregroundColor(.blue)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(.systemBackground))
                            .cornerRadius(8)
                            .shadow(color: .black.opacity(0.05), radius: 2)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGroupedBackground))
                
                // --- 2. History & Transaction Portals ---
                VStack(spacing: 12) {
                    NavigationLink(destination: MonthlyExpensesView(monthKey: currentYearMonthKey, monthLabel: currentMonthString)) {
                        HStack {
                            Image(systemName: "doc.text.magnifyingglass")
                            Text("View \(currentMonthString) Expenses")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .font(.subheadline.bold())
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(10)
                    }
                    
                    // Quick Entry Add Expense Action
                    Button(action: { showAddExpenseSheet = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Log a New Expenditure")
                        }
                        .font(.subheadline.bold())
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green.opacity(0.1))
                        .foregroundColor(.green)
                        .cornerRadius(10)
                    }
                    .disabled(categories.isEmpty)
                }
                .padding()
                
                // --- 3. Category Dashboard Table View ---
                List {
                    Section {
                        HStack {
                            Text("Categories Dashboard").font(.subheadline.bold())
                            Spacer()
                            Button(action: { showQuickAddCategory = true }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus")
                                    Text("Quick Add")
                                }
                                .font(.caption.bold())
                            }
                        }
                        .listRowBackground(Color.clear)
                        
                        if categories.isEmpty {
                            ContentUnavailableView("No Categories Active", systemImage: "folder.badge.plus", description: Text("Tap Quick Add above to bootstrap your spending layout limits."))
                        } else {
                            ForEach(categories) { category in
                                let spent = category.totalSpent(for: selectedDate)
                                let limit = category.monthlyLimit
                                let ratio = limit > 0 ? min(spent / limit, 1.0) : 0.0
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text("\(category.emoji) \(category.name)")
                                            .font(.body.bold())
                                        Spacer()
                                        Text("\(spent, format: .currency(code: "EUR")) / \(limit, format: .currency(code: "EUR"))")
                                            .font(.caption.monospaced())
                                            .foregroundColor(spent > limit ? .red : .secondary)
                                    }
                                    
                                    // Custom visual threshold indicator progress metrics bar
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            Capsule()
                                                .fill(Color(.systemGray5))
                                                .frame(height: 8)
                                            Capsule()
                                                .fill(spent > limit ? Color.red : (ratio > 0.85 ? Color.orange : Color.blue))
                                                .frame(width: geo.size.width * ratio, height: 8)
                                        }
                                    }
                                    .frame(height: 8)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    
                    // --- 4. Deep Setup Target Forward Navigation View ---
                    Section {
                        NavigationLink(destination: ManageCategoriesView()) {
                            HStack {
                                Image(systemName: "gearshape.2")
                                    .foregroundColor(.blue)
                                Text("Manage All Categories Screen")
                                Spacer()
                            }
                            .foregroundColor(.primary)
                        }
                        
                        NavigationLink(destination: DataBackupView()) {
                            HStack {
                                Image(systemName: "arrow.up.arrow.down.circle")
                                    .foregroundColor(.green)
                                Text("Backup & Restore Data")
                                Spacer()
                            }
                            .foregroundColor(.primary)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Main Hub")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: DataBackupView()) {
                        Image(systemName: "externaldrive.badge.icloud")
                    }
                }
            }
            
            // Sheet triggers for adding content
            .sheet(isPresented: $showQuickAddCategory) { QuickAddCategoryView() }
            .sheet(isPresented: $showAddExpenseSheet) { QuickAddExpenseView(categories: categories, initialDate: selectedDate) }
            
            // Native Dialog pop-up text entry engine wrapper to configure limits
            .alert("Set Deposit Pool for \(currentMonthString)", isPresented: $showEditPoolAlert) {
                TextField("Amount (€)", text: $poolInputString)
                    .keyboardType(.decimalPad)
                Button("Save", action: updateMonthlyPoolAmount)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Specify total available currency volume injected into the \(currentMonthString) tracker calculations.")
            }
        }
    }
    
    // MARK: - Month Navigation
    
    private func changeMonth(by offset: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: offset, to: selectedDate) {
            selectedDate = newDate
        }
    }
    
    private func resetToCurrentMonth() {
        selectedDate = Date()
    }
    
    private func updateMonthlyPoolAmount() {
        guard let value = Double(poolInputString) else { return }
        if let existingPool = currentMonthlyPool {
            existingPool.totalAmount = value
        } else {
            let newPool = MonthlyPool(yearMonthString: currentYearMonthKey, totalAmount: value)
            modelContext.insert(newPool)
        }
    }
}
