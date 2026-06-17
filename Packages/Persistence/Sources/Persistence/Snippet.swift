import Foundation
import SwiftData

/// Snippet de commande réutilisable, synchronisé via **CloudKit** (comme les
/// profils). Données déclaratives — pas de code exécutable téléchargé (conforme
/// App Store 2.5.2).
///
/// Modèle compatible CloudKit : aucune contrainte `.unique`, tous les attributs
/// ont une valeur par défaut.
@Model
public final class Snippet {
    public var id: UUID = UUID()
    public var title: String = ""
    public var command: String = ""
    public var createdAt: Date = Date()

    public init(id: UUID = UUID(), title: String, command: String, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.command = command
        self.createdAt = createdAt
    }
}
