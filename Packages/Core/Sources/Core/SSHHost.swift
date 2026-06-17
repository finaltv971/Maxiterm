import Foundation

/// Description immuable d'un hôte SSH à contacter.
///
/// Aucune donnée secrète n'est stockée ici : les identifiants vivent dans
/// ``SSHCredential`` et, à terme, dans le Keychain / la Secure Enclave.
public struct SSHHost: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID
    /// Libellé affiché à l'utilisateur (ex. « Mac mini maison »).
    public let label: String
    /// Nom d'hôte ou adresse IP.
    public let hostname: String
    public let port: Int
    public let username: String

    public init(
        id: UUID = UUID(),
        label: String,
        hostname: String,
        port: Int = 22,
        username: String
    ) {
        self.id = id
        self.label = label
        self.hostname = hostname
        self.port = port
        self.username = username
    }

    /// Retourne une nouvelle copie avec le libellé modifié (pattern immuable).
    public func withLabel(_ newLabel: String) -> SSHHost {
        SSHHost(id: id, label: newLabel, hostname: hostname, port: port, username: username)
    }
}

public extension SSHHost {
    /// Valide les champs au niveau de la frontière du système.
    /// - Returns: la liste des erreurs de validation (vide si l'hôte est valide).
    func validationErrors() -> [String] {
        var errors: [String] = []
        if hostname.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append("Le nom d'hôte est requis.")
        }
        if username.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append("Le nom d'utilisateur est requis.")
        }
        if !(1...65535).contains(port) {
            errors.append("Le port doit être compris entre 1 et 65535.")
        }
        return errors
    }

    var isValid: Bool { validationErrors().isEmpty }
}
