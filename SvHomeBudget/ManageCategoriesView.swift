import SwiftUI
import SwiftData

struct ManageCategoriesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExpenseCategory.name) private var categories: [ExpenseCategory]
    
    // State to trigger addition or modification screens
    @State private var showAddCategorySheet = false
    @State private var categoryToEdit: ExpenseCategory?
    
    var body: some View {
        List {
            if categories.isEmpty {
                ContentUnavailableView(
                    "No Categories Found",
                    systemImage: "folder.badge.plus",
                    description: Text("Tap the '+' button above to construct your budgeting layout framework.")
                )
            } else {
                ForEach(categories) { category in
                    HStack {
                        Text(category.emoji)
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(category.name)
                                .font(.body.bold())
                            Text("Limit: \(category.monthlyLimit, format: .currency(code: "EUR"))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // EDIT BUTTON
                        Button(action: { categoryToEdit = category }) {
                            Image(systemName: "pencil.circle.fill")
                                .font(.title2)
                                .foregroundColor(.orange)
                        }
                        .buttonStyle(.plain) // Keeps only the button area clickable
                    }
                    .padding(.vertical, 4)
                }
                .onDelete(perform: deleteCategoryNode) // NATIVE SWIPE-TO-REMOVE
            }
        }
        .navigationTitle("Manage Categories")
        .toolbar {
            // ADD BUTTON inside navigation bar
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showAddCategorySheet = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        // Sheet for ADDING a new category
        .sheet(isPresented: $showAddCategorySheet) {
            CategoryFormSheet(title: "Add Category") { name, emoji, limit in
                let newCat = ExpenseCategory(name: name, emoji: emoji, monthlyLimit: limit)
                modelContext.insert(newCat)
            }
        }
        // Sheet for EDITING an existing category
        .sheet(item: $categoryToEdit) { category in
            CategoryFormSheet(
                title: "Edit Category",
                initialName: category.name,
                initialEmoji: category.emoji,
                initialLimit: category.monthlyLimit
            ) { updatedName, updatedEmoji, updatedLimit in
                // Directly mutate the properties; SwiftData automatically saves changes
                category.name = updatedName
                category.emoji = updatedEmoji
                category.monthlyLimit = updatedLimit
            }
        }
    }
    
    private func deleteCategoryNode(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(categories[index])
        }
    }
}
