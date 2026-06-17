import Foundation
import Security

/// Stockage des secrets (mots de passe, clés privées) dans le Keychain iOS.
///
/// Chaque secret est indexé par l'`id` du profil. Les valeurs ne transitent
/// jamais par SwiftData ni par les journaux.
public struct KeychainSecretStore: Sendable {
    public enum KeychainError: LocalizedError {
        case unexpectedStatus(OSStatus)

        public var errorDescription: String? {
            switch self {
            case let .unexpectedStatus(status):
                return "Erreur Keychain (code \(status))."
            }
        }
    }

    /// Nature du secret stocké pour un profil. Chaque nature occupe un item
    /// Keychain distinct (compte dérivé de l'`id`).
    public enum Kind: Sendable {
        case secret // mot de passe ou clé privée
        case passphrase // phrase de passe d'une clé privée chiffrée
        case jumpSecret // secret du jump host (ProxyJump)
        case jumpPassphrase // phrase de passe de la clé du jump host

        fileprivate func account(for id: UUID) -> String {
            switch self {
            case .secret: return id.uuidString
            case .passphrase: return id.uuidString + ".passphrase"
            case .jumpSecret: return id.uuidString + ".jump"
            case .jumpPassphrase: return id.uuidString + ".jump.passphrase"
            }
        }
    }

    private let service: String

    public init(service: String = "fr.digistream.maxiterm.secrets") {
        self.service = service
    }

    /// Enregistre (ou remplace) un secret associé à un profil.
    ///
    /// L'item est marqué **synchronizable** : il suit via le **trousseau iCloud**
    /// vers les autres appareils de l'utilisateur.
    public func setSecret(_ secret: String, for id: UUID, kind: Kind = .secret) throws {
        let data = Data(secret.utf8)
        let query = baseQuery(for: id, kind: kind)

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var insert = query
            insert[kSecValueData as String] = data
            insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            let addStatus = SecItemAdd(insert as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.unexpectedStatus(addStatus)
            }
        default:
            throw KeychainError.unexpectedStatus(updateStatus)
        }
    }

    /// Lit un secret d'un profil, ou `nil` s'il n'existe pas.
    public func secret(for id: UUID, kind: Kind = .secret) throws -> String? {
        var query = baseQuery(for: id, kind: kind)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            guard let data = item as? Data else { return nil }
            return String(data: data, encoding: .utf8)
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// Supprime un secret d'un profil (silencieux s'il n'existe pas).
    public func deleteSecret(for id: UUID, kind: Kind = .secret) throws {
        let status = SecItemDelete(baseQuery(for: id, kind: kind) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    private func baseQuery(for id: UUID, kind: Kind) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: kind.account(for: id),
            // Domaine « synchronisable » : items partagés via le trousseau iCloud.
            kSecAttrSynchronizable as String: kCFBooleanTrue as Any,
        ]
    }
}
