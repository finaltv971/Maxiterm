import Persistence
import SwiftData
import SwiftUI

/// Gestion des snippets de commandes (création, édition, suppression).
/// Synchronisés via iCloud (CloudKit) comme les profils.
struct SnippetsManagerView: View {
    @EnvironmentObject private var store: ProfileStore
    @Query(sort: [SortDescriptor(\Snippet.title)]) private var snippets: [Snippet]
    @State private var editor: SnippetEditor.Target?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if snippets.isEmpty {
                ContentUnavailableView(
                    "Aucun snippet",
                    systemImage: "text.badge.plus",
                    description: Text("Enregistrez des commandes réutilisables, synchronisées via iCloud.")
                )
            } else {
                List {
                    ForEach(snippets) { snippet in
                        Button { editor = .edit(snippet) } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(snippet.title).font(.headline)
                                Text(snippet.command)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .tint(.primary)
                    }
                    .onDelete(perform: delete)
                }
            }
        }
        .navigationTitle("Snippets")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { editor = .create } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Nouveau snippet")
            }
        }
        .sheet(item: $editor) { target in
            SnippetEditor(target: target).environmentObject(store)
        }
        .alert("Erreur", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        ), presenting: errorMessage) { _ in
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text($0) }
    }

    private func delete(_ offsets: IndexSet) {
        do {
            for index in offsets where snippets.indices.contains(index) {
                try store.deleteSnippet(snippets[index])
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Création / édition d'un snippet.
struct SnippetEditor: View {
    enum Target: Identifiable {
        case create
        case edit(Snippet)

        var id: String {
            switch self {
            case .create: return "create"
            case let .edit(snippet): return snippet.id.uuidString
            }
        }
    }

    @EnvironmentObject private var store: ProfileStore
    @Environment(\.dismiss) private var dismiss
    let target: Target

    @State private var title = ""
    @State private var command = ""
    @State private var errorMessage: String?

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
            && !command.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Titre") {
                    TextField("ex. Mettre à jour le système", text: $title)
                }
                Section("Commande") {
                    TextField("ex. sudo apt update && sudo apt upgrade -y", text: $command, axis: .vertical)
                        .font(.system(.body, design: .monospaced))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .lineLimit(2 ... 6)
                }
            }
            .navigationTitle(isEditing ? "Modifier le snippet" : "Nouveau snippet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer", action: save).disabled(!canSave)
                }
            }
            .onAppear(perform: prefill)
            .alert("Erreur", isPresented: Binding(
                get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
            ), presenting: errorMessage) { _ in
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: { Text($0) }
        }
    }

    private var isEditing: Bool {
        if case .edit = target { return true }
        return false
    }

    private func prefill() {
        if case let .edit(snippet) = target {
            title = snippet.title
            command = snippet.command
        }
    }

    private func save() {
        do {
            switch target {
            case .create:
                try store.createSnippet(title: title, command: command)
            case let .edit(snippet):
                try store.updateSnippet(snippet, title: title, command: command)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
