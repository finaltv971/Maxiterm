import Persistence
import SSHKit

extension ProfileStore {
    /// Assemble la configuration de jump host (ProxyJump) d'un profil — hôte,
    /// identifiant (Keychain) et clé hôte connue (TOFU) — ou `nil` si aucun jump.
    func jumpConfig(for profile: SSHProfile) -> SSHJumpConfig? {
        guard let jump = try? jumpConnection(for: profile) else { return nil }
        let hostID = KnownHostsStore.hostID(hostname: jump.host.hostname, port: jump.host.port)
        return SSHJumpConfig(
            host: jump.host,
            credential: jump.credential,
            knownHostKey: knownHosts.key(forHostID: hostID)
        )
    }
}
