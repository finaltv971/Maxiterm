import Core
import Foundation
import SwiftData

/// Façade `@MainActor` de persistance des profils : combine SwiftData (modèles)
/// et le Keychain (secrets). Expose le `ModelContainer` pour permettre l'usage
/// de `@Query` côté SwiftUI.
@MainActor
public final class ProfileStore: ObservableObject {
    public let container: ModelContainer
    private let secrets: KeychainSecretStore

    /// Clés hôtes mémorisées (TOFU).
    public let knownHosts: KnownHostsStore

    public init(
        container: ModelContainer,
        secrets: KeychainSecretStore = KeychainSecretStore(),
        knownHosts: KnownHostsStore = KnownHostsStore()
    ) {
        self.container = container
        self.secrets = secrets
        self.knownHosts = knownHosts
    }

    /// Container CloudKit identifier (doit correspondre à l'entitlement iCloud).
    public static let cloudKitContainerID = "iCloud.fr.digistream.maxiterm"

    /// Store applicatif : tente la **synchronisation iCloud (CloudKit)** et se
    /// replie sur un stockage **local** si iCloud est indisponible (entitlement
    /// ou compte iCloud absent).
    public static func makeDefault() throws -> ProfileStore {
        let cloudConfiguration = ModelConfiguration(
            cloudKitDatabase: .private(cloudKitContainerID)
        )
        if let cloud = try? ModelContainer(for: SSHProfile.self, configurations: cloudConfiguration) {
            return ProfileStore(container: cloud)
        }
        return ProfileStore(container: try ModelContainer(for: SSHProfile.self))
    }

    /// Store en mémoire (tests / prévisualisations).
    public static func makeInMemory() throws -> ProfileStore {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return ProfileStore(container: try ModelContainer(for: SSHProfile.self, configurations: configuration))
    }

    private var context: ModelContext { container.mainContext }

    public func allProfiles() throws -> [SSHProfile] {
        let descriptor = FetchDescriptor<SSHProfile>(
            sortBy: [
                SortDescriptor(\.lastUsedAt, order: .reverse),
                SortDescriptor(\.label),
            ]
        )
        return try context.fetch(descriptor)
    }

    /// Crée un profil et stocke son secret au Keychain.
    @discardableResult
    public func create(
        label: String,
        hostname: String,
        port: Int,
        username: String,
        authMethod: ProfileAuthMethod,
        secret: String,
        passphrase: String? = nil,
        jump: JumpInput? = nil
    ) throws -> SSHProfile {
        let profile = SSHProfile(
            label: label,
            hostname: hostname,
            port: port,
            username: username,
            authMethod: authMethod
        )
        context.insert(profile)
        try secrets.setSecret(secret, for: profile.id)
        try applyPassphrase(passphrase, to: profile.id)
        try applyJump(jump, to: profile)
        try context.save()
        return profile
    }

    /// Met à jour un profil ; remplace le secret et/ou la phrase de passe fournis.
    /// Une `passphrase` vide efface la phrase de passe enregistrée.
    public func update(
        _ profile: SSHProfile,
        secret: String?,
        passphrase: String? = nil,
        jump: JumpInput? = nil
    ) throws {
        if let secret, !secret.isEmpty {
            try secrets.setSecret(secret, for: profile.id)
        }
        if let passphrase {
            try applyPassphrase(passphrase, to: profile.id)
        }
        try applyJump(jump, to: profile)
        try context.save()
    }

    public func delete(_ profile: SSHProfile) throws {
        let id = profile.id
        context.delete(profile)
        try context.save()
        for kind in [KeychainSecretStore.Kind.secret, .passphrase, .jumpSecret, .jumpPassphrase] {
            try secrets.deleteSecret(for: id, kind: kind)
        }
    }

    /// Applique la configuration du jump host : métadonnées + secret au Keychain.
    private func applyJump(_ jump: JumpInput?, to profile: SSHProfile) throws {
        guard let jump else { return }
        profile.jumpHostname = jump.hostname
        profile.jumpPort = jump.port
        profile.jumpUsername = jump.username
        profile.jumpAuthMethod = jump.authMethod

        if jump.hostname.isEmpty {
            // Jump désactivé : on purge ses secrets.
            try secrets.deleteSecret(for: profile.id, kind: .jumpSecret)
            try secrets.deleteSecret(for: profile.id, kind: .jumpPassphrase)
            return
        }
        if let secret = jump.secret, !secret.isEmpty {
            try secrets.setSecret(secret, for: profile.id, kind: .jumpSecret)
        }
        if let passphrase = jump.passphrase {
            if passphrase.isEmpty {
                try secrets.deleteSecret(for: profile.id, kind: .jumpPassphrase)
            } else {
                try secrets.setSecret(passphrase, for: profile.id, kind: .jumpPassphrase)
            }
        }
    }

    /// Hôte et identifiant du jump host d'un profil, ou `nil` s'il n'y en a pas
    /// (ou si son secret manque).
    public func jumpConnection(for profile: SSHProfile) throws -> (host: SSHHost, credential: SSHCredential)? {
        guard profile.usesJumpHost else { return nil }
        guard
            let secret = try secrets.secret(for: profile.id, kind: .jumpSecret), !secret.isEmpty
        else { return nil }
        let passphrase = try secrets.secret(for: profile.id, kind: .jumpPassphrase)
        return (profile.jumpSSHHost, profile.jumpCredential(withSecret: secret, passphrase: passphrase))
    }

    /// Stocke ou efface la phrase de passe d'une clé privée chiffrée.
    private func applyPassphrase(_ passphrase: String?, to id: UUID) throws {
        guard let passphrase else { return }
        if passphrase.isEmpty {
            try secrets.deleteSecret(for: id, kind: .passphrase)
        } else {
            try secrets.setSecret(passphrase, for: id, kind: .passphrase)
        }
    }

    public func markUsed(_ profile: SSHProfile) {
        profile.lastUsedAt = Date()
        try? context.save()
    }

    /// Construit l'identifiant de connexion en lisant le secret (et, pour une clé
    /// privée chiffrée, la phrase de passe) du Keychain.
    public func credential(for profile: SSHProfile) throws -> SSHCredential? {
        guard let secret = try secrets.secret(for: profile.id), !secret.isEmpty else { return nil }
        let passphrase = try secrets.secret(for: profile.id, kind: .passphrase)
        return profile.credential(withSecret: secret, passphrase: passphrase)
    }
}
