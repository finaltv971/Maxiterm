import Foundation

/// Mémorise les clés hôtes acceptées (TOFU), indexées par `hôte:port`.
///
/// Les clés hôtes ne sont **pas secrètes** (elles sont publiques) : on les
/// stocke dans `UserDefaults`, pas dans le Keychain. La valeur est la chaîne
/// de clé publique OpenSSH (`algorithme base64`).
public struct KnownHostsStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let storageKey = "fr.digistream.maxiterm.knownHosts"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Identifiant canonique d'un hôte.
    public static func hostID(hostname: String, port: Int) -> String {
        "\(hostname):\(port)"
    }

    private func all() -> [String: String] {
        defaults.dictionary(forKey: storageKey) as? [String: String] ?? [:]
    }

    /// Clé OpenSSH mémorisée pour un hôte, ou `nil`.
    public func key(forHostID hostID: String) -> String? {
        all()[hostID]
    }

    /// Mémorise (ou remplace) la clé d'un hôte.
    public func remember(_ openSSHKey: String, forHostID hostID: String) {
        var dictionary = all()
        dictionary[hostID] = openSSHKey
        defaults.set(dictionary, forKey: storageKey)
    }

    /// Oublie la clé d'un hôte (force un nouveau TOFU à la prochaine connexion).
    public func forget(hostID: String) {
        var dictionary = all()
        dictionary.removeValue(forKey: hostID)
        defaults.set(dictionary, forKey: storageKey)
    }

    public func isKnown(hostID: String) -> Bool {
        all()[hostID] != nil
    }
}
