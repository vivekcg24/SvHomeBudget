import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct DataBackupView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query private var categories: [ExpenseCategory]
    @Query private var allExpenses: [Expense]
    @Query private var pools: [MonthlyPool]
    
    // File Exporter states
    @State private var showFileExporter = false
    @State private var exportDocument: BackupDocument?
    @State private var exportFilename: String = "SvHomeBudget-Backup.json"
    
    // ShareLink state
    @State private var temporaryShareURL: URL?
    
    // File Importer states
    @State private var showFileImporter = false
    @State private var pendingBackup: BackupData?
    @State private var showImportConfirmation = false
    
    // Feedback alerts
    @State private var showSuccessAlert = false
    @State private var successMessage: String = ""
    @State private var showErrorAlert = false
    @State private var errorMessage: String = ""
    
    var body: some View {
        List {
            // --- 1. Current Database Status Overview ---
            Section {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "externaldrive.badge.icloud")
                            .font(.system(size: 36))
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Local Storage Status")
                                .font(.headline)
                            Text("All records are securely stored locally on device.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    
                    Divider()
                    
                    HStack(spacing: 20) {
                        statPill(label: "Categories", count: categories.count, icon: "folder.fill", color: .purple)
                        statPill(label: "Expenses", count: allExpenses.count, icon: "receipt.fill", color: .orange)
                        statPill(label: "Pools", count: pools.count, icon: "banknote.fill", color: .green)
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Database Overview")
            }
            
            // --- 2. Export Section ---
            Section {
                Button(action: prepareAndTriggerExport) {
                    HStack {
                        Image(systemName: "square.and.arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Export Backup File")
                                .font(.body.bold())
                                .foregroundColor(.primary)
                            Text("Save a JSON backup to Files, iCloud Drive, or external storage.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                if let shareURL = temporaryShareURL {
                    ShareLink(item: shareURL, preview: SharePreview("SvHomeBudget Backup", image: Image(systemName: "archivebox.fill"))) {
                        HStack {
                            Image(systemName: "paperplane.circle.fill")
                                .font(.title2)
                                .foregroundColor(.teal)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Share Backup File")
                                    .font(.body.bold())
                                    .foregroundColor(.primary)
                                Text("AirDrop, message, or email your latest exported backup.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                Text("Export Data")
            } footer: {
                Text("Export creates a complete, timestamped JSON snapshot of your categories, expenditures, and monthly budget pools.")
            }
            
            // --- 3. Import Section ---
            Section {
                Button(action: { showFileImporter = true }) {
                    HStack {
                        Image(systemName: "square.and.arrow.down.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Import Backup File")
                                .font(.body.bold())
                                .foregroundColor(.primary)
                            Text("Restore from a previously exported .json backup file.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("Import Data")
            } footer: {
                Text("You can choose to either merge the backup with existing data or completely replace current records.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Backup & Restore")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            generateShareURLIfPossible()
        }
        
        // Native Document Exporter
        .fileExporter(
            isPresented: $showFileExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: exportFilename
        ) { result in
            switch result {
            case .success(let url):
                successMessage = "Backup successfully exported to:\n\(url.lastPathComponent)"
                showSuccessAlert = true
            case .failure(let error):
                errorMessage = error.localizedDescription
                showErrorAlert = true
            }
        }
        
        // Native Document Importer
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleFileImporterResult(result)
        }
        
        // Import Strategy Confirmation Dialog
        .confirmationDialog(
            "Import Options",
            isPresented: $showImportConfirmation,
            titleVisibility: .visible
        ) {
            Button("Merge with Existing Data") {
                if let backup = pendingBackup {
                    applyImport(backup: backup, mode: .merge)
                }
            }
            Button("Replace All Existing Data", role: .destructive) {
                if let backup = pendingBackup {
                    applyImport(backup: backup, mode: .replace)
                }
            }
            Button("Cancel", role: .cancel) {
                pendingBackup = nil
            }
        } message: {
            if let backup = pendingBackup {
                Text("Found \(backup.categories.count) categories, \(backup.expenses.count) expenses, and \(backup.monthlyPools.count) monthly budget pools in this backup.\n\nChoose 'Merge' to combine with existing data, or 'Replace' to clear current records.")
            } else {
                Text("Select an import strategy.")
            }
        }
        
        // Success Alert
        .alert("Import / Export Status", isPresented: $showSuccessAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(successMessage)
        }
        
        // Error Alert
        .alert("Error", isPresented: $showErrorAlert) {
            Button("Dismiss", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Helper Views
    
    private func statPill(label: String, count: Int, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundColor(color)
                Text("\(count)")
                    .font(.headline.bold())
            }
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.08))
        .cornerRadius(8)
    }
    
    // MARK: - Export Logic
    
    private func prepareAndTriggerExport() {
        do {
            let data = try DataBackupManager.exportBackup(
                categories: categories,
                expenses: allExpenses,
                pools: pools
            )
            let dateString = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: ":", with: "-")
                .replacingOccurrences(of: " ", with: "_")
            exportFilename = "SvHomeBudget-Backup-\(dateString).json"
            exportDocument = BackupDocument(data: data)
            showFileExporter = true
            
            // Also refresh share URL
            writeTemporaryShareFile(data: data, filename: exportFilename)
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
    
    private func generateShareURLIfPossible() {
        guard !categories.isEmpty || !allExpenses.isEmpty || !pools.isEmpty else { return }
        if let data = try? DataBackupManager.exportBackup(categories: categories, expenses: allExpenses, pools: pools) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let filename = "SvHomeBudget-Backup-\(formatter.string(from: Date())).json"
            writeTemporaryShareFile(data: data, filename: filename)
        }
    }
    
    private func writeTemporaryShareFile(data: Data, filename: String) {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? data.write(to: tempURL, options: .atomic)
        temporaryShareURL = tempURL
    }
    
    // MARK: - Import Logic
    
    private func handleFileImporterResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Access to the selected file was denied by system security."
                showErrorAlert = true
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            
            do {
                let data = try Data(contentsOf: url)
                let backup = try DataBackupManager.decodeBackup(from: data)
                self.pendingBackup = backup
                self.showImportConfirmation = true
            } catch {
                errorMessage = error.localizedDescription
                showErrorAlert = true
            }
            
        case .failure(let error):
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
    
    private func applyImport(backup: BackupData, mode: ImportMode) {
        do {
            let summary = try DataBackupManager.importBackup(backup, into: modelContext, mode: mode)
            let modeText = mode == .replace ? "replaced" : "merged"
            successMessage = "Successfully \(modeText) backup data!\n\n• Categories: \(summary.categoriesCount)\n• Expenses: \(summary.expensesCount)\n• Budget Pools: \(summary.poolsCount)"
            showSuccessAlert = true
            generateShareURLIfPossible()
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
}
