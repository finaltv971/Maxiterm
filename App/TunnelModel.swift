import Core
import Foundation
import Persistence
import SSHKit

/// Pilote l'écran ``TunnelView`` : ouvre une connexion SSH (avec jump host
/// éventuel) et gère un **port forwarding local** vers un service distant.
@MainActor
final class TunnelModel: ObservableObject {
    enum Status: Equatable {
        case idle
        case connecting
        case active(localPort: Int)
        case failed(String)
    }

    @Published private(set) var status: Status = .idle

    private let host: SSHHost
    private let credential: SSHCredential
    private let knownHosts: KnownHostsStore
    private let jump: SSHJumpConfig?

    private var connection: SSHRawConnection?
    private var forward: LocalForward?

    init(host: SSHHost, credential: SSHCredential, knownHosts: KnownHostsStore, jump: SSHJumpConfig?) {
        self.host = host
        self.credential = credential
        self.knownHosts = knownHosts
        self.jump = jump
    }

    /// Ouvre la connexion (si besoin) et démarre le forwarding local.
    func start(remoteHost: String, remotePort: Int, localPort: Int) async {
        status = .connecting
        do {
            let connection = try await ensureConnection()
            let forward = try await connection.startLocalForward(
                localPort: localPort,
                remoteHost: remoteHost,
                remotePort: remotePort
            )
            self.forward = forward
            status = .active(localPort: forward.localPort)
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    /// Arrête le forwarding sans fermer la connexion.
    func stopForward() async {
        await forward?.stop()
        forward = nil
        status = .idle
    }

    /// Ferme tout (à la disparition de l'écran).
    func stop() async {
        await forward?.stop()
        forward = nil
        await connection?.close()
        connection = nil
    }

    private func ensureConnection() async throws -> SSHRawConnection {
        if let connection { return connection }
        let hostID = KnownHostsStore.hostID(hostname: host.hostname, port: host.port)
        let knownKey = knownHosts.key(forHostID: hostID)
        let connection: SSHRawConnection
        if let jump {
            connection = try await SSHRawConnection.connectThroughJump(
                jump: jump,
                target: host,
                targetCredential: credential,
                targetKnownHostKey: knownKey
            )
        } else {
            connection = try await SSHRawConnection.connect(
                to: host,
                credential: credential,
                knownHostKey: knownKey
            )
        }
        self.connection = connection
        return connection
    }
}
