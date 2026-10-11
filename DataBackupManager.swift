import Foundation
import SwiftData
import UniformTypeIdentifiers
import SwiftUI

// MARK: - Backup Transfer Data Models (DTOs)

struct BackupData: Codable {
    var version: Int = 1
    var exportDate: Date = Date()
    var categories: [CategoryBackupDTO]
    var expenses: [ExpenseBackupDTO]
    var monthlyPools: [MonthlyPoolBackupDTO]
    
    init(
        version: Int = 1,
        exportDate: Date = Date(),
        categories: [CategoryBackupDTO] = [],
        expenses: [ExpenseBackupDTO] = [],
        monthlyPools: [MonthlyPoolBackupDTO] = []
    ) {
        self.version = version
        self.exportDate = exportDate
        self.categories = categories
        self.expenses = expenses
        self.monthlyPools = monthlyPools
    }
}

struct CategoryBackupDTO: Codable, Identifiable {
    var id: UUID
    var name: String
    var emoji: String
    var monthlyLimit: Double
    
    init(id: UUID = UUID(), name: String, emoji: String, monthlyLimit: Double) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.monthlyLimit = monthlyLimit
    }
}

struct ExpenseBackupDTO: Codable, Identifiable {
    var id: UUID
    var amount: Double
    var date: Date
    var note: String
    var categoryId: UUID?
    
    init(id: UUID = UUID(), amount: Double, date: Date, note: String, categoryId: UUID? = nil) {
        self.id = id
        self.amount = amount
        self.date = date
        self.note = note
        self.categoryId = categoryId
    }
}

struct MonthlyPoolBackupDTO: Codable, Identifiable {
    var id: UUID
    var yearMonthString: String
    var totalAmount: Double
    
    init(id: UUID = UUID(), yearMonthString: String, totalAmount: Double) {
        self.id = id
        self.yearMonthString = yearMonthString
        self.totalAmount = totalAmount
    }
}

// MARK: - Import Mode & Summary

enum ImportMode {
    case merge
    case replace
}

struct ImportSummary: Equatable {
    var categoriesCount: Int
    var expensesCount: Int
    var poolsCount: Int
}

enum BackupError: LocalizedError {
    case invalidFileData
    case decodingFailed(String)
    case encodingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidFileData:
            return "The selected file is empty or could not be read."
        case .decodingFailed(let reason):
            return "Failed to parse backup file: \(reason)"
        case .encodingFailed(let reason):
            return "Failed to generate backup: \(reason)"
        }
    }
}

// MARK: - Backup File Document for SwiftUI File Exporter

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    
    var data: Data
    
    init(data: Data = Data()) {
        self.data = data
    }
    
    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Data Backup Manager Engine

final class DataBackupManager {
    
    static func exportBackup(
        categories: [ExpenseCategory],
        expenses: [Expense],
        pools: [MonthlyPool]
    ) throws -> Data {
        let catDTOs = categories.map {
            CategoryBackupDTO(
                id: $0.id,
                name: $0.name,
                emoji: $0.emoji,
                monthlyLimit: $0.monthlyLimit
            )
        }
        
        let expDTOs = expenses.map {
            ExpenseBackupDTO(
                id: $0.id,
                amount: $0.amount,
                date: $0.date,
                note: $0.note,
                categoryId: $0.category?.id
            )
        }
        
        let poolDTOs = pools.map {
            MonthlyPoolBackupDTO(
                id: $0.id,
                yearMonthString: $0.yearMonthString,
                totalAmount: $0.totalAmount
            )
        }
        
        let backup = BackupData(
            categories: catDTOs,
            expenses: expDTOs,
            monthlyPools: poolDTOs
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            return try encoder.encode(backup)
        } catch {
            throw BackupError.encodingFailed(error.localizedDescription)
        }
    }
    
    static func decodeBackup(from data: Data) throws -> BackupData {
        guard !data.isEmpty else {
            throw BackupError.invalidFileData
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(BackupData.self, from: data)
        } catch {
            throw BackupError.decodingFailed(error.localizedDescription)
        }
    }
    
    static func importBackup(
        _ backup: BackupData,
        into context: ModelContext,
        mode: ImportMode
    ) throws -> ImportSummary {
        if mode == .replace {
            // Delete all existing entities
            let existingExpenses = try context.fetch(FetchDescriptor<Expense>())
            for e in existingExpenses { context.delete(e) }
            
            let existingCategories = try context.fetch(FetchDescriptor<ExpenseCategory>())
            for c in existingCategories { context.delete(c) }
            
            let existingPools = try context.fetch(FetchDescriptor<MonthlyPool>())
            for p in existingPools { context.delete(p) }
            
            try context.save()
            
            // Reinsert categories
            var categoryMap: [UUID: ExpenseCategory] = [:]
            for catDTO in backup.categories {
                let cat = ExpenseCategory(name: catDTO.name, emoji: catDTO.emoji, monthlyLimit: catDTO.monthlyLimit)
                cat.id = catDTO.id
                context.insert(cat)
                categoryMap[catDTO.id] = cat
            }
            
            // Reinsert expenses
            for expDTO in backup.expenses {
                let exp = Expense(amount: expDTO.amount, date: expDTO.date, note: expDTO.note)
                exp.id = expDTO.id
                if let catId = expDTO.categoryId, let cat = categoryMap[catId] {
                    exp.category = cat
                    cat.expenses.append(exp)
                }
                context.insert(exp)
            }
            
            // Reinsert pools
            for poolDTO in backup.monthlyPools {
                let pool = MonthlyPool(yearMonthString: poolDTO.yearMonthString, totalAmount: poolDTO.totalAmount)
                pool.id = poolDTO.id
                context.insert(pool)
            }
            
            try context.save()
            
            return ImportSummary(
                categoriesCount: backup.categories.count,
                expensesCount: backup.expenses.count,
                poolsCount: backup.monthlyPools.count
            )
        } else {
            // MERGE MODE
            let existingCategories = try context.fetch(FetchDescriptor<ExpenseCategory>())
            var categoryMap: [UUID: ExpenseCategory] = [:]
            for c in existingCategories {
                categoryMap[c.id] = c
            }
            
            for catDTO in backup.categories {
                if let existing = categoryMap[catDTO.id] {
                    existing.name = catDTO.name
                    existing.emoji = catDTO.emoji
                    existing.monthlyLimit = catDTO.monthlyLimit
                } else if let matchByName = existingCategories.first(where: { $0.name.caseInsensitiveCompare(catDTO.name) == .orderedSame }) {
                    matchByName.emoji = catDTO.emoji
                    matchByName.monthlyLimit = catDTO.monthlyLimit
                    categoryMap[catDTO.id] = matchByName
                } else {
                    let newCat = ExpenseCategory(name: catDTO.name, emoji: catDTO.emoji, monthlyLimit: catDTO.monthlyLimit)
                    newCat.id = catDTO.id
                    context.insert(newCat)
                    categoryMap[catDTO.id] = newCat
                }
            }
            
            let existingExpenses = try context.fetch(FetchDescriptor<Expense>())
            var expenseMap: [UUID: Expense] = [:]
            for e in existingExpenses {
                expenseMap[e.id] = e
            }
            
            for expDTO in backup.expenses {
                if let existing = expenseMap[expDTO.id] {
                    existing.amount = expDTO.amount
                    existing.date = expDTO.date
                    existing.note = expDTO.note
                    if let catId = expDTO.categoryId, let cat = categoryMap[catId] {
                        existing.category = cat
                    }
                } else {
                    let newExp = Expense(amount: expDTO.amount, date: expDTO.date, note: expDTO.note)
                    newExp.id = expDTO.id
                    if let catId = expDTO.categoryId, let cat = categoryMap[catId] {
                        newExp.category = cat
                        cat.expenses.append(newExp)
                    }
                    context.insert(newExp)
                    expenseMap[expDTO.id] = newExp
                }
            }
            
            let existingPools = try context.fetch(FetchDescriptor<MonthlyPool>())
            for poolDTO in backup.monthlyPools {
                if let existing = existingPools.first(where: { $0.yearMonthString == poolDTO.yearMonthString }) {
                    existing.totalAmount = poolDTO.totalAmount
                } else {
                    let newPool = MonthlyPool(yearMonthString: poolDTO.yearMonthString, totalAmount: poolDTO.totalAmount)
                    newPool.id = poolDTO.id
                    context.insert(newPool)
                }
            }
            
            try context.save()
            
            return ImportSummary(
                categoriesCount: backup.categories.count,
                expensesCount: backup.expenses.count,
                poolsCount: backup.monthlyPools.count
            )
        }
    }
}
