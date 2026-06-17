import Foundation
import StoreKit

/// Gère le « tip jar » : achats **consommables** facultatifs pour soutenir le
/// projet. **Ne débloque aucune fonctionnalité** — l'app reste 100% gratuite.
@MainActor
final class TipStore: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published var thankYouShown = false
    @Published var errorMessage: String?

    private let productIDs = [
        "fr.digistream.maxiterm.tip.small",
        "fr.digistream.maxiterm.tip.medium",
        "fr.digistream.maxiterm.tip.large",
    ]

    func loadProducts() async {
        do {
            let loaded = try await Product.products(for: productIDs)
            products = loaded.sorted { $0.price < $1.price }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func purchase(_ product: Product) async {
        do {
            let result = try await product.purchase()
            switch result {
            case let .success(verification):
                if case let .verified(transaction) = verification {
                    await transaction.finish() // consommable : rien à débloquer
                    thankYouShown = true
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
