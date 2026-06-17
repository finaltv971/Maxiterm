import StoreKit
import SwiftUI

/// Écran « Soutenir le projet » : pourboires facultatifs, sans aucun déblocage.
struct TipJarView: View {
    @StateObject private var store = TipStore()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("100% gratuit, sans abonnement", systemImage: "heart.fill")
                            .font(.headline)
                            .foregroundStyle(.pink)
                        Text(
                            "Toutes les fonctions sont et resteront gratuites. Si MaxiTerm "
                                + "vous est utile, un pourboire aide à financer le développement — "
                                + "**il ne débloque rien**."
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("Offrir un pourboire") {
                    if store.products.isEmpty {
                        HStack {
                            ProgressView().controlSize(.small)
                            Text("Chargement…").foregroundStyle(.secondary)
                        }
                    } else {
                        ForEach(store.products, id: \.id) { product in
                            Button {
                                Task { await store.purchase(product) }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(product.displayName)
                                        Text(product.description)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(product.displayPrice)
                                        .font(.body.monospacedDigit())
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Soutenir")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
            .task { await store.loadProducts() }
            .alert("Merci ! ☕️", isPresented: $store.thankYouShown) {
                Button("Avec plaisir") {}
            } message: {
                Text("Votre soutien fait la différence.")
            }
            .alert(
                "Erreur",
                isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } }),
                presenting: store.errorMessage
            ) { _ in
                Button("OK", role: .cancel) { store.errorMessage = nil }
            } message: { Text($0) }
        }
    }
}
