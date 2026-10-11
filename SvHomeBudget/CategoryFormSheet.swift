import SwiftUI
import SwiftData

struct CategoryFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let title: String
    @State private var name: String
    @State private var emoji: String
    @State private var limitString: String
    
    // Callback function triggered when the user saves changes
    var onSave: (String, String, Double) -> Void
    
    // Custom constructor allowing default initial settings for edit states
    init(
        title: String,
        initialName: String = "",
        initialEmoji: String = "🛒",
        initialLimit: Double = 0.0,
        onSave: @escaping (String, String, Double) -> Void
    ) {
        self.title = title
        self._name = State(initialValue: initialName)
        self._emoji = State(initialValue: initialEmoji)
        self._limitString = State(initialValue: initialLimit > 0 ? String(format: "%.2f", initialLimit) : "")
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Category Details")) {
                    TextField("Name (e.g. Dining)", text: $name)
                    
                    TextField("Emoji Representation Icon", text: $emoji)
                        .frame(width: 50)
                        .onChange(of: emoji) { _, newValue in
                            // Keeps the input field limited to 1 character (ideally 1 emoji)
                            if newValue.count > 1 {
                                emoji = String(newValue.prefix(1))
                            }
                        }
                    
                    TextField("Monthly Allocation Limit (€)", text: $limitString)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let parsedLimit = Double(limitString) ?? 0.0
                        onSave(name.trimmingCharacters(in: .whitespacesAndNewlines), emoji, parsedLimit)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
