import Core
import Foundation
import SwiftData

/// Méthode d'authentification enregistrée pour un profil.
public enum ProfileAuthMethod: String, Codable, Sendable, CaseIterable {
    case password
    // Valeur brute conservée pour compatibilité de stockage.
    case privateKey = "ed25519"

    public var displayName: String {
        switch self {
        case .password: return "Mot de passe"
        case .privateKey: return "Clé privée"
        }
    }
}

/// Profil SSH persisté (SwiftData).
///
/// > Sécurité : **aucun secret** n'est stocké ici. Le mot de passe ou la clé
/// > privée vit dans le Keychain (voir ``KeychainSecretStore``), référencé par
/// > `id`. Ce modèle ne contient que des métadonnées de connexion.
// Modèle compatible **CloudKit** : pas de contrainte `.unique` (interdite par
// CloudKit) et chaque attribut possède une valeur par défaut (exigence SwiftData
// + CloudKit). L'unicité logique est assurée par `id`.
@Model
public final class SSHProfile {
    public var id: UUID = UUID()
    public var label: String = ""
    public var hostname: String = ""
    public var port: Int = 22
    public var username: String = ""
    public var authMethod: ProfileAuthMethod = ProfileAuthMethod.password
    public var createdAt: Date = Date()
    public var lastUsedAt: Date?

    // Jump host (ProxyJump) optionnel : un `jumpHostname` non vide l'active.
    public var jumpHostname: String = ""
    public var jumpPort: Int = 22
    public var jumpUsername: String = ""
    public var jumpAuthMethod: ProfileAuthMethod = ProfileAuthMethod.password

    public init(
        id: UUID = UUID(),
        label: String,
        hostname: String,
        port: Int = 22,
        username: String,
        authMethod: ProfileAuthMethod = .password,
        createdAt: Date = Date(),
        lastUsedAt: Date? = nil,
        jumpHostname: String = "",
        jumpPort: Int = 22,
        jumpUsername: String = "",
        jumpAuthMethod: ProfileAuthMethod = .password
    ) {
        self.id = id
        self.label = label
        self.hostname = hostname
        self.port = port
        self.username = username
        self.authMethod = authMethod
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.jumpHostname = jumpHostname
        self.jumpPort = jumpPort
        self.jumpUsername = jumpUsername
        self.jumpAuthMethod = jumpAuthMethod
    }

    /// `true` si un jump host (ProxyJump) est configuré.
    public var usesJumpHost: Bool { !jumpHostname.isEmpty }
}

public extension SSHProfile {
    /// DTO de transport (value type Sendable) consommé par la couche SSH.
    var host: SSHHost {
        SSHHost(
            id: id,
            label: label.isEmpty ? hostname : label,
            hostname: hostname,
            port: port,
            username: username
        )
    }

    /// Construit l'identifiant SSH à partir de la méthode du profil et du secret
    /// lu dans le Keychain. `passphrase` déchiffre une clé privée protégée.
    func credential(withSecret secret: String, passphrase: String? = nil) -> SSHCredential {
        switch authMethod {
        case .password:
            return .password(secret)
        case .privateKey:
            return .privateKeyPEM(privateKey: secret, passphrase: passphrase)
        }
    }

    /// Hôte du jump host (ProxyJump), si configuré.
    var jumpSSHHost: SSHHost {
        SSHHost(label: jumpHostname, hostname: jumpHostname, port: jumpPort, username: jumpUsername)
    }

    /// Identifiant du jump host à partir de son secret.
    func jumpCredential(withSecret secret: String, passphrase: String? = nil) -> SSHCredential {
        switch jumpAuthMethod {
        case .password:
            return .password(secret)
        case .privateKey:
            return .privateKeyPEM(privateKey: secret, passphrase: passphrase)
        }
    }
}

/// Paramètres de configuration d'un jump host transmis au store.
public struct JumpInput: Sendable {
    public var hostname: String
    public var port: Int
    public var username: String
    public var authMethod: ProfileAuthMethod
    public var secret: String? // nil = inchangé
    public var passphrase: String? // nil = inchangé

    public init(
        hostname: String,
        port: Int,
        username: String,
        authMethod: ProfileAuthMethod,
        secret: String? = nil,
        passphrase: String? = nil
    ) {
        self.hostname = hostname
        self.port = port
        self.username = username
        self.authMethod = authMethod
        self.secret = secret
        self.passphrase = passphrase
    }
}
