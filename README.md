# SvHomeBudget

SvHomeBudget is a modern, native iOS personal expense and budget management application built with **SwiftUI** and Apple's **SwiftData** framework. It provides local-first persistence, reactive UI updates, visual budget tracking with threshold alerts, monthly budget pooling, historic/future cycle month navigation, and full data export/import capabilities.

---

## Table of Contents

- [Overview](#overview)
- [Key Features](#key-features)
- [Technology Stack](#technology-stack)
- [Architecture & Data Flow](#architecture--data-flow)
- [Data Models & Schema](#data-models--schema)
  - [ExpenseCategory](#expensecategory)
  - [Expense](#expense)
  - [MonthlyPool](#monthlypool)
- [View Hierarchy & UI Structure](#view-hierarchy--ui-structure)
  - [Main Dashboard (ContentView)](#main-dashboard-contentview)
  - [Monthly Expenses (MonthlyExpensesView)](#monthly-expenses-monthlyexpensesview)
  - [Category Management (ManageCategoriesView & CategoryFormSheet)](#category-management-managecategoriesview--categoryformsheet)
  - [Quick Entry Views (QuickAddCategoryView & QuickAddExpenseView)](#quick-entry-views-quickaddcategoryview--quickaddexpenseview)
  - [Backup & Restore (DataBackupView)](#backup--restore-databackupview)
- [Business Logic & Calculations](#business-logic--calculations)
  - [Monthly Spending Calculations](#monthly-spending-calculations)
  - [Pool Reduction on Expense Logging](#pool-reduction-on-expense-logging)
  - [Visual Threshold Indicators](#visual-threshold-indicators)
  - [Monthly Budget Pool Keying](#monthly-budget-pool-keying)
  - [Data Backup & Restore Engine (DataBackupManager)](#data-backup--restore-engine-databackupmanager)
- [Unit Testing](#unit-testing)
- [Getting Started](#getting-started)
  - [Requirements](#requirements)
  - [Build and Run](#build-and-run)
  - [Running Tests](#running-tests)
- [Future Enhancements](#future-enhancements)

---

## Overview

SvHomeBudget empowers users to maintain financial discipline through:
- Allocating budget categories with individual spending caps.
- Logging daily expenditures linked to specific categories.
- Monitoring month-to-date spending against custom limits in real time.
- Navigating freely between current, past, and future monthly cycles.
- Configuring a dedicated monthly deposit pool for holistic cycle tracking.
- Keeping 100% of user data on-device with zero remote server dependency.
- Backing up, exporting, and restoring complete financial data via standard JSON files.

---

## Key Features

- **Local-First Persistence**: Full offline capability using SwiftData with zero external SDKs.
- **Reactive UI**: Immediate dashboard synchronisation upon data mutations via SwiftUI `@Query` macros.
- **Multi-Month Cycle Stepper**: Header stepper (`◀` and `▶`) allowing users to seamlessly review historical months or plan future budget cycles with instant recalculation of spending ratios and pool balances.
- **Dynamic Visual Progress Bars**: Color-coded indicators representing spending progress:
  - 🔵 **Blue**: Normal spending ($\le 85\%$ of limit).
  - 🟠 **Orange**: Approaching threshold ($> 85\%$ of limit).
  - 🔴 **Red**: Over budget ($> 100\%$ of limit).
- **Monthly Deposit Pool Deduction**: Dedicated monthly budget target stored per cycle (`yyyy-MM`). Automatically decrements in real time whenever an expense is logged.
- **Data Export & Import (Backup & Restore)**:
  - Export complete snapshot (categories, expenses, monthly pools) to JSON via native `fileExporter` or system `ShareLink`.
  - Import JSON backups via native `fileImporter` with choice of **Merge** or **Replace** modes.
- **Cascade Deletion**: SwiftData relationship delete rules ensure child expenses are safely handled when categories are removed.
- **Input Validation**: Safeguards against invalid decimal strings, empty category names, and restricts emoji inputs to single characters.

---

## Technology Stack

| Component | Technology | Description |
| :--- | :--- | :--- |
| **Language** | Swift 5.9+ | Modern Swift features and concurrency |
| **UI Framework** | SwiftUI | Declarative user interface |
| **Data Persistence** | SwiftData | Apple's schema-driven persistence framework |
| **Document Export / Import** | UniformTypeIdentifiers + FileDocument | Native JSON file importing and exporting |
| **Testing** | XCTest + SwiftData | Unit testing with in-memory model containers |
| **IDE / Target** | Xcode 16+ / iOS 17.0+ | Native Apple platform targeting |

---

## Architecture & Data Flow

SvHomeBudget follows modern declarative SwiftUI patterns with direct SwiftData context injection:

```
                      ┌──────────────────────┐
                      │   SvHomeBudgetApp    │
                      │  (.modelContainer)   │
                      └──────────┬───────────┘
                                 │
                                 ▼
                      ┌──────────────────────┐
                      │     ContentView      │
                      │  (@Query categories) │
                      │  (@Query pools)      │
                      │  (@Query expenses)   │
                      │  (@State selectedDate│
                      └───────┬──┬──┬──┬─────┘
                              │  │  │  │
        ┌─────────────────────┘  │  │  └──────────────────────┐
        ▼                        ▼  ▼                         ▼
┌───────────────┐  ┌──────────────────┐  ┌─────────────────┐  ┌──────────────────┐
│Quick Add Modal│  │MonthlyExpenses   │  │ManageCategories │  │  DataBackupView  │
│  - Category   │  │  - By month key  │  │  - Add / Edit   │  │  - Export JSON   │
│  - Expense    │  │  - Swipe delete  │  │  - Cascade del │  │  - Import (Merge/ │
│  (DatePicker &│  └──────────────────┘  └─────────────────┘  │    Replace mode) │
│   Pool deduct)│                                             └──────────────────┘
└───────────────┘
```

1. **Root Injection**: `SvHomeBudgetApp` initializes the SwiftData container with `[ExpenseCategory.self, Expense.self, MonthlyPool.self]` using `.modelContainer(...)`.
2. **Environment Propagation**: `modelContext` is inherited by child views via `@Environment(\.modelContext)`.
3. **Reactive Binding**: `@Query` automates view re-rendering whenever models change or are inserted/deleted.

---

## Data Models & Schema

Defined in `SvHomeBudget/Models.swift`:

### ExpenseCategory
Represents a user-defined spending category (e.g., Groceries, Utilities, Entertainment).

```swift
@Model
final class ExpenseCategory {
    var id: UUID = UUID()
    var name: String
    var emoji: String
    var monthlyLimit: Double
    
    @Relationship(deleteRule: .cascade, inverse: \Expense.category)
    var expenses: [Expense] = []
}
```
- **Relationships**: One-to-many relationship with `Expense`. Deleting a category cascades deletions to all associated expenses.
- **Computed Method**: `totalSpent(for date: Date) -> Double` calculates sum of expenses recorded in the same calendar month and year.

### Expense
Represents a single monetary transaction.

```swift
@Model
final class Expense {
    var id: UUID = UUID()
    var amount: Double
    var date: Date
    var note: String
    var category: ExpenseCategory?
}
```
- **Relationships**: Many-to-one inverse relationship with `ExpenseCategory`.

### MonthlyPool
Represents the designated lump-sum budget pool for a specific month.

```swift
@Model
final class MonthlyPool {
    var id: UUID = UUID()
    var yearMonthString: String // Format: "YYYY-MM" (e.g. "2026-10")
    var totalAmount: Double
    
    func deduct(amount: Double) {
        totalAmount -= amount
    }
}
```

---

## View Hierarchy & UI Structure

### Main Dashboard (`ContentView.swift`)
- **Header**:
  - Chevron buttons (`◀` and `▶`) to step backward and forward through monthly cycles.
  - Cycle status indicator ("Current Cycle" vs. "Historical Cycle" with a one-tap "• Today" reset button).
  - "Added Pool" trigger button showing remaining deposit pool formatted in EUR for the active month. Tapping opens an alert to configure that month's budget.
- **Action Hub**:
  - Navigation button to `MonthlyExpensesView` dynamically labeled for the active month (e.g. "View October 2026 Expenses").
  - "Log a New Expenditure" button (disabled when no categories exist).
- **Categories Dashboard**:
  - Displays each category with name, emoji, progress bar, and spending ratio `€spent / €limit` dynamically evaluated for the selected cycle month.
  - Includes a "Quick Add" toolbar button and deep link to `ManageCategoriesView`.
- **Navigation Links**:
  - Link to `ManageCategoriesView` for category editing and deletion.
  - Link to `DataBackupView` and trailing navigation bar button for backup/restore.

### Monthly Expenses (`MonthlyExpensesView.swift`)
- **Summary Section**: Displays aggregated spending across all categories for the selected `yyyy-MM` cycle.
- **Transaction History**: Lists individual expenditures sorted by date in descending order.
- **Deletion**: Native swipe-to-delete via `.onDelete(perform: removeLogItem)`.

### Category Management (`ManageCategoriesView.swift` & `CategoryFormSheet.swift`)
- **ManageCategoriesView**:
  - Sorted category listing (`@Query(sort: \ExpenseCategory.name)`).
  - Edit button per item to trigger modification modal.
  - Native swipe-to-delete with automatic cascade deletion of associated transactions.
  - Navigation bar `+` button to add new categories.
- **CategoryFormSheet**:
  - Reusable sheet used for both adding and editing categories.
  - Automatically restricts emoji input to a single character.
  - Save button disables when category name is blank or whitespace-only.

### Quick Entry Views (`QuickAddCategoryView.swift`)
- **QuickAddCategoryView**: Compact sheet for rapid category onboarding.
- **QuickAddExpenseView**: Streamlined modal to log expenses with amount, note, interactive `DatePicker` (defaulting to the currently viewed dashboard cycle), and category picker. Automatically deducts the charged amount from the active monthly pool.

### Backup & Restore (`DataBackupView.swift`)
- **Database Overview**: Displays current count of stored categories, expenses, and pools.
- **Export Section**:
  - Exports a timestamped JSON file (`SvHomeBudget-Backup-YYYYMMdd-HHmmss.json`) via `.fileExporter`.
  - Native `ShareLink` to AirDrop, message, or email backup files.
- **Import Section**:
  - Opens `.fileImporter` supporting `.json` files.
  - Confirmation dialog with strategy choice:
    - **Merge**: Merges incoming categories and expenses, preserving existing unique entries.
    - **Replace**: Completely replaces existing local data with backup contents.

---

## Business Logic & Calculations

### Monthly Spending Calculations
In `ExpenseCategory.swift`:
```swift
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
```

### Pool Reduction on Expense Logging
In `QuickAddCategoryView.swift`:
```swift
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
```

### Data Backup & Restore Engine (`DataBackupManager.swift`)
- **`exportBackup(categories:expenses:pools:)`**: Encodes entities into a versioned `BackupData` Codable DTO using ISO-8601 timestamps and sorted, pretty-printed JSON formatting.
- **`decodeBackup(from:)`**: Decodes and validates JSON backup integrity.
- **`importBackup(_:into:mode:)`**:
  - In **replace mode**, clears existing stores and restores all entities with relationship links reconstructed.
  - In **merge mode**, updates matched categories by ID/name, preserves or creates expenses with correct category linkages, and synchronizes monthly pools.

---

## Unit Testing

Tests are located in `SvHomeBudgetTests/SvHomeBudgetTests.swift` and use `XCTest` with in-memory SwiftData containers:

- **Isolated Canvas**: Each test runs with `ModelConfiguration(isStoredInMemoryOnly: true)` to prevent test contamination.
- **Coverage**:
  - `testCategoryTotalSpentCalculatesCorrectlyForCurrentMonth`: Validates multi-item summation within the current cycle.
  - `testCategoryTotalSpentExcludesPastMonths`: Validates that transactions from previous months are excluded from the current cycle total.
  - `testMonthlyPoolDeductAmount`: Validates deducting an amount from a monthly pool.
  - `testMultipleExpensesDeductFromPool`: Validates cumulative deductions across multiple logged expenses.
  - `testExportBackupGeneratesValidJSON`: Validates JSON schema encoding, field retention, and relationship integrity.
  - `testImportBackupReplaceMode`: Tests total wiping of old data and reconstruction of new imported data and relationships.
  - `testImportBackupMergeMode`: Tests non-destructive combination and updating of categories and expenses.
  - `testDecodeBackupThrowsOnInvalidData`: Validates error handling on empty or corrupted file inputs.

---

## Getting Started

### Requirements
- macOS 14.0+ (Sonoma or newer)
- Xcode 15.0+ (Xcode 16 recommended)
- iOS 17.0+ deployment target

### Build and Run
1. Open `SvHomeBudget.xcodeproj` in Xcode.
2. Select an iOS Simulator or connected device (iOS 17+).
3. Press `Cmd + R` to build and run.

### Running Tests
1. In Xcode, press `Cmd + U` or run the test plan from the Test Navigator.
2. Ensure all unit tests pass cleanly.

---

## Future Enhancements

- 📊 **Spending Charts & Analytics**: Visual monthly breakdowns with Apple Swift Charts.
- 💱 **Multi-Currency Support**: Configurable currency symbol beyond the default EUR (€).
- 🏷️ **Tags & Search**: Full-text search and tagging across expense history.
- 🔔 **Budget Alerts**: Local notifications when category spending exceeds 85% or 100%.
