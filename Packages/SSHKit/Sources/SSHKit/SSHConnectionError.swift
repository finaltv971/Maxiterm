import Foundation

/// Erreurs exposées par ``SSHSession``, avec des messages prêts pour l'UI.
public enum SSHConnectionError: LocalizedError, Sendable {
    case invalidHost(reason: String)
    case authenticationFailed
    case connectionFailed(underlying: String)
    case sessionClosed
    case notConnected
    /// La clé hôte présentée ne correspond pas à celle mémorisée (possible MITM).
    case hostKeyChanged(fingerprint: String)

    public var errorDescription: String? {
        switch self {
        case let .invalidHost(reason):
            return "Hôte invalide : \(reason)"
        case .authenticationFailed:
            return "Échec de l'authentification. Vérifiez l'identifiant et le secret."
        case let .connectionFailed(underlying):
            return "Connexion impossible : \(underlying)"
        case .sessionClosed:
            return "La session SSH a été fermée."
        case .notConnected:
            return "Aucune session SSH active."
        case let .hostKeyChanged(fingerprint):
            return "⚠️ La clé hôte a changé (\(fingerprint)). "
                + "Attaque potentielle de l'homme du milieu. Connexion refusée. "
                + "Si ce changement est légitime, réinitialisez la clé connue dans le profil."
        }
    }
}
