import Persistence
import SwiftData
import SwiftUI

/// Barre de commande du terminal : envoi à l'onglet actif **ou** diffusion à
/// tous les onglets (**MultiExec**), avec insertion rapide de **snippets**.
struct CommandBar: View {
    @ObservedObject var model: TerminalTabsModel
    @Query(sort: [SortDescriptor(\Snippet.title)]) private var snippets: [Snippet]
    @State private var command = ""
    @State private var broadcast = false

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Menu {
                    if snippets.isEmpty {
                        Text("Aucun snippet")
                    } else {
                        ForEach(snippets) { snippet in
                            Button(snippet.title) { command = snippet.command }
                        }
                    }
                } label: {
                    Image(systemName: "text.badge.plus")
                }
                .accessibilityLabel("Snippets")

                TextField(placeholder, text: $command)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onSubmit(send)

                Button(action: send) {
                    Image(systemName: "paperplane.fill")
                }
                .disabled(command.isEmpty)
            }

            Toggle(isOn: $broadcast) {
                Label("MultiExec — diffuser à tous les onglets", systemImage: "dot.radiowaves.left.and.right")
                    .font(.caption)
            }
            .tint(.orange)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var placeholder: String {
        broadcast ? "Commande → tous les onglets" : "Commande → onglet actif"
    }

    private func send() {
        guard !command.isEmpty else { return }
        if broadcast {
            model.broadcast(command)
        } else {
            model.sendToSelected(command)
        }
        command = ""
    }
}
