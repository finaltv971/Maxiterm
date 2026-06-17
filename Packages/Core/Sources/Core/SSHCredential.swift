import Foundation

/// Méthode d'authentification choisie pour une session SSH.
///
/// > Sécurité : ne jamais journaliser une valeur de ``SSHCredential``. Les
/// > secrets sont persistés dans le Keychain (voir la couche `Persistence`).
public enum SSHCredential: Sendable {
    /// Authentification par mot de passe.
    case password(String)
    /// Authentification par clé privée OpenSSH (PEM) — Ed25519 ou ECDSA.
    /// La phrase de passe déchiffre éventuellement la clé.
    case privateKeyPEM(privateKey: String, passphrase: String?)

    /// Indique si la méthode requiert un secret non vide.
    public var hasSecret: Bool {
        switch self {
        case let .password(value):
            return !value.isEmpty
        case let .privateKeyPEM(privateKey, _):
            return !privateKey.isEmpty
        }
    }
}

extension SSHCredential: CustomStringConvertible {
    /// Description sûre : ne divulgue jamais le secret.
    public var description: String {
        switch self {
        case .password:
            return "SSHCredential.password(••••)"
        case .privateKeyPEM:
            return "SSHCredential.privateKeyPEM(••••)"
        }
    }
}
