import XCTest
import SwiftData
@testable import SvHomeBudget

@MainActor
final class SvHomeBudgetTests: XCTestCase {
    
    var modelContainer: ModelContainer!
    var context: ModelContext!

    // This runs BEFORE every single test to give you a clean, empty database canvas
    override func setUpWithError() throws {
        // 1. Force the configuration to run strictly in RAM
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        
        // 2. Instantiate the container with your real app schema models
        modelContainer = try ModelContainer(for: ExpenseCategory.self, Expense.self, MonthlyPool.self, configurations: config)
        context = modelContainer.mainContext
    }

    // This runs AFTER every single test to wipe memory clean
    override func tearDownWithError() throws {
        modelContainer = nil
        context = nil
    }

    // --- YOUR UNIT TESTS ---

    func testCategoryTotalSpentCalculatesCorrectlyForCurrentMonth() throws {
        // Arrange: Create a category
        let groceries = ExpenseCategory(name: "Groceries", emoji: "🍏", monthlyLimit: 500.0)
        context.insert(groceries)
        
        // Arrange: Create two expenses happening TODAY (Current Month)
        let expense1 = Expense(amount: 50.0, date: Date(), note: "Supermarket")
        let expense2 = Expense(amount: 25.50, date: Date(), note: "Bakery")
        
        context.insert(expense1)
        context.insert(expense2)
        
        // Link them to the category
        groceries.expenses.append(expense1)
        groceries.expenses.append(expense2)
        
        // Act: Run your model's calculation function
        let calculatedTotal = groceries.totalSpent(for: Date())
        
        // Assert: Ensure the math is exactly right
        XCTAssertEqual(calculatedTotal, 75.50, "The total spent calculation should accurately sum up the current month's items.")
    }

    func testCategoryTotalSpentExcludesPastMonths() throws {
        // Arrange: Create a category
        let leisure = ExpenseCategory(name: "Leisure", emoji: "🍿", monthlyLimit: 200.0)
        context.insert(leisure)
        
        // Arrange: Create an expense from 3 months ago (Past Month)
        let threeMonthsAgo = Calendar.current.date(byAdding: .month, value: -3, to: Date())!
        let oldExpense = Expense(amount: 100.0, date: threeMonthsAgo, note: "Summer Concert")
        
        context.insert(oldExpense)
        leisure.expenses.append(oldExpense)
        
        // Act: Request calculations for TODAY's date context
        let currentMonthTotal = leisure.totalSpent(for: Date())
        
        // Assert: The math should completely ignore the historical item
        XCTAssertEqual(currentMonthTotal, 0.0, "Expenses from past months must be filtered out of the current month calculation view.")
    }

    func testMonthlyPoolDeductAmount() throws {
        // Arrange: Create a monthly pool
        let pool = MonthlyPool(yearMonthString: "2026-10", totalAmount: 1000.0)
        context.insert(pool)
        
        // Act: Deduct expense amount
        pool.deduct(amount: 150.0)
        
        // Assert: Pool is reduced accordingly
        XCTAssertEqual(pool.totalAmount, 850.0, accuracy: 0.001, "Deducting from the pool should correctly subtract the expense amount.")
    }

    func testMultipleExpensesDeductFromPool() throws {
        // Arrange: Create a monthly pool and category
        let pool = MonthlyPool(yearMonthString: "2026-10", totalAmount: 500.0)
        let dining = ExpenseCategory(name: "Dining", emoji: "🍕", monthlyLimit: 300.0)
        context.insert(pool)
        context.insert(dining)
        
        // Act: Simulate adding multiple expenses and reducing the pool
        let expenses = [35.0, 42.50, 18.25]
        for amount in expenses {
            let expense = Expense(amount: amount, date: Date(), note: "Meal", category: dining)
            context.insert(expense)
            dining.expenses.append(expense)
            pool.deduct(amount: amount)
        }
        
        // Assert: Pool reflects all deductions
        let expectedRemaining = 500.0 - (35.0 + 42.50 + 18.25)
        XCTAssertEqual(pool.totalAmount, expectedRemaining, accuracy: 0.001, "Multiple expense deductions should accumulate on the pool.")
    }

    // --- DATA BACKUP & RESTORE TESTS ---

    func testExportBackupGeneratesValidJSON() throws {
        // Arrange
        let category = ExpenseCategory(name: "Utilities", emoji: "⚡️", monthlyLimit: 120.0)
        context.insert(category)
        let expense = Expense(amount: 45.0, date: Date(), note: "Electricity", category: category)
        context.insert(expense)
        category.expenses.append(expense)
        let pool = MonthlyPool(yearMonthString: "2026-10", totalAmount: 800.0)
        context.insert(pool)
        
        // Act
        let exportData = try DataBackupManager.exportBackup(
            categories: [category],
            expenses: [expense],
            pools: [pool]
        )
        
        // Assert
        XCTAssertFalse(exportData.isEmpty, "Exported backup data should not be empty.")
        let decoded = try DataBackupManager.decodeBackup(from: exportData)
        XCTAssertEqual(decoded.version, 1)
        XCTAssertEqual(decoded.categories.count, 1)
        XCTAssertEqual(decoded.categories.first?.name, "Utilities")
        XCTAssertEqual(decoded.categories.first?.emoji, "⚡️")
        XCTAssertEqual(decoded.expenses.count, 1)
        XCTAssertEqual(decoded.expenses.first?.amount, 45.0)
        XCTAssertEqual(decoded.expenses.first?.categoryId, category.id)
        XCTAssertEqual(decoded.monthlyPools.count, 1)
        XCTAssertEqual(decoded.monthlyPools.first?.totalAmount, 800.0)
    }

    func testImportBackupReplaceMode() throws {
        // Arrange: Existing data that should be wiped
        let oldCategory = ExpenseCategory(name: "Old Stuff", emoji: "📦", monthlyLimit: 50.0)
        context.insert(oldCategory)
        let oldPool = MonthlyPool(yearMonthString: "2026-09", totalAmount: 100.0)
        context.insert(oldPool)
        try context.save()
        
        // Create backup data with new items
        let newCatId = UUID()
        let catDTO = CategoryBackupDTO(id: newCatId, name: "Health", emoji: "💊", monthlyLimit: 150.0)
        let expDTO = ExpenseBackupDTO(id: UUID(), amount: 30.0, date: Date(), note: "Pharmacy", categoryId: newCatId)
        let poolDTO = MonthlyPoolBackupDTO(id: UUID(), yearMonthString: "2026-10", totalAmount: 900.0)
        let backup = BackupData(categories: [catDTO], expenses: [expDTO], monthlyPools: [poolDTO])
        
        // Act: Import with replace mode
        let summary = try DataBackupManager.importBackup(backup, into: context, mode: .replace)
        
        // Assert
        XCTAssertEqual(summary.categoriesCount, 1)
        XCTAssertEqual(summary.expensesCount, 1)
        XCTAssertEqual(summary.poolsCount, 1)
        
        let fetchedCategories = try context.fetch(FetchDescriptor<ExpenseCategory>())
        XCTAssertEqual(fetchedCategories.count, 1)
        XCTAssertEqual(fetchedCategories.first?.name, "Health")
        XCTAssertFalse(fetchedCategories.contains { $0.name == "Old Stuff" }, "Old category should be replaced.")
        
        let fetchedExpenses = try context.fetch(FetchDescriptor<Expense>())
        XCTAssertEqual(fetchedExpenses.count, 1)
        XCTAssertEqual(fetchedExpenses.first?.note, "Pharmacy")
        XCTAssertEqual(fetchedExpenses.first?.category?.name, "Health", "Imported expense should be correctly linked to category.")
        
        let fetchedPools = try context.fetch(FetchDescriptor<MonthlyPool>())
        XCTAssertEqual(fetchedPools.count, 1)
        XCTAssertEqual(fetchedPools.first?.totalAmount, 900.0)
    }

    func testImportBackupMergeMode() throws {
        // Arrange: Existing category
        let existingCategory = ExpenseCategory(name: "Groceries", emoji: "🥦", monthlyLimit: 400.0)
        context.insert(existingCategory)
        let existingPool = MonthlyPool(yearMonthString: "2026-10", totalAmount: 500.0)
        context.insert(existingPool)
        try context.save()
        
        // Backup containing an update for Groceries, plus a new category and expense
        let newCatId = UUID()
        let updateGroceriesDTO = CategoryBackupDTO(id: existingCategory.id, name: "Groceries", emoji: "🍏", monthlyLimit: 450.0)
        let newCategoryDTO = CategoryBackupDTO(id: newCatId, name: "Transport", emoji: "🚗", monthlyLimit: 200.0)
        let newExpenseDTO = ExpenseBackupDTO(id: UUID(), amount: 25.0, date: Date(), note: "Bus pass", categoryId: newCatId)
        let poolDTO = MonthlyPoolBackupDTO(id: UUID(), yearMonthString: "2026-11", totalAmount: 700.0)
        let backup = BackupData(
            categories: [updateGroceriesDTO, newCategoryDTO],
            expenses: [newExpenseDTO],
            monthlyPools: [poolDTO]
        )
        
        // Act: Import with merge mode
        let summary = try DataBackupManager.importBackup(backup, into: context, mode: .merge)
        
        // Assert
        XCTAssertEqual(summary.categoriesCount, 2)
        XCTAssertEqual(summary.expensesCount, 1)
        XCTAssertEqual(summary.poolsCount, 1)
        
        let fetchedCategories = try context.fetch(FetchDescriptor<ExpenseCategory>())
        XCTAssertEqual(fetchedCategories.count, 2, "Merge mode should keep existing category and add new one.")
        let groceries = fetchedCategories.first { $0.name == "Groceries" }
        XCTAssertEqual(groceries?.emoji, "🍏", "Existing category should be updated with new emoji.")
        XCTAssertEqual(groceries?.monthlyLimit, 450.0, "Existing category should be updated with new limit.")
        
        let transport = fetchedCategories.first { $0.name == "Transport" }
        XCTAssertNotNil(transport)
        
        let fetchedExpenses = try context.fetch(FetchDescriptor<Expense>())
        XCTAssertEqual(fetchedExpenses.count, 1)
        XCTAssertEqual(fetchedExpenses.first?.category?.name, "Transport")
        
        let fetchedPools = try context.fetch(FetchDescriptor<MonthlyPool>())
        XCTAssertEqual(fetchedPools.count, 2, "Should retain 2026-10 pool and add 2026-11 pool.")
    }

    func testDecodeBackupThrowsOnInvalidData() {
        // Arrange
        let emptyData = Data()
        let corruptedData = "{\"notAValidBackup\": true}".data(using: .utf8)!
        
        // Act & Assert
        XCTAssertThrowsError(try DataBackupManager.decodeBackup(from: emptyData)) { error in
            guard case BackupError.invalidFileData = error else {
                XCTFail("Expected invalidFileData error but got \(error)")
                return
            }
        }
        
        XCTAssertThrowsError(try DataBackupManager.decodeBackup(from: corruptedData)) { error in
            guard case BackupError.decodingFailed = error else {
                XCTFail("Expected decodingFailed error but got \(error)")
                return
            }
        }
    }
}
