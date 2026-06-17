import Core
import Foundation
import Persistence
import SSHKit
import TerminalUI

/// Coordonne une ``SSHSession`` (actor) et un ``TerminalEmulator`` (MainActor)
/// pour le compte de ``TerminalScreen``.
///
/// Câblage :
/// - frappes clavier / resize de l'émulateur  → `SSHSession.send/resize`
/// - flux de sortie de la session             → `TerminalEmulator.feed`
@MainActor
final class SessionViewModel: ObservableObject {
    enum Status: Equatable {
        case connecting
        case connected
        case failed(String)
        case closed
    }

    @Published private(set) var status: Status = .connecting

    let emulator = TerminalEmulator()

    private let session = SSHSession()
    private var lifecycleTask: Task<Void, Never>?
    private var logger: SessionLogger?

    /// Ouvre la connexion et démarre les boucles d'I/O.
    func start(
        host: SSHHost,
        credential: SSHCredential,
        knownHosts: KnownHostsStore,
        logStore: SessionLogStore,
        jump: SSHJumpConfig? = nil
    ) {
        guard lifecycleTask == nil else { return }

        let target = "\(host.username)@\(host.hostname):\(host.port)"
        let logger = SessionLogger(store: logStore, profileLabel: host.label, target: target, kind: "terminal")
        self.logger = logger
        if let jump {
            logger.info("Ouverture d'une session terminal vers \(target) via \(jump.host.hostname)")
        } else {
            logger.info("Ouverture d'une session terminal vers \(target)")
        }

        let hostID = KnownHostsStore.hostID(hostname: host.hostname, port: host.port)
        let knownKey = knownHosts.key(forHostID: hostID)

        emulator.onInput = { [weak self] data in
            guard let self else { return }
            Task { await self.session.send(data) }
        }
        emulator.onResize = { [weak self] cols, rows in
            guard let self else { return }
            Task { await self.session.resize(cols: cols, rows: rows) }
        }

        lifecycleTask = Task { [weak self] in
            guard let self else { return }

            // Draine la sortie distante vers l'émulateur (tâche MainActor).
            let drain = Task { [weak self] in
                guard let self else { return }
                for await chunk in await self.session.terminalOutput {
                    self.emulator.feed(chunk)
                }
            }

            do {
                try await self.session.connect(
                    to: host,
                    credential: credential,
                    knownHostKey: knownKey,
                    jump: jump
                )
                if let learned = await self.session.learnedHostKey() {
                    knownHosts.remember(learned, forHostID: hostID)
                    logger.info("Clé hôte mémorisée (TOFU) : \(HostKeyFingerprint.sha256(forOpenSSHKey: learned))")
                }
                self.status = .connected
                logger.info("Connecté")
            } catch {
                self.status = .failed(error.localizedDescription)
                logger.error(error.localizedDescription)
            }

            await drain.value
            if self.status == .connected {
                self.status = .closed
            }
            logger.info("Session fermée")
            logger.finish()
        }
    }

    /// Ferme la session (à appeler quand l'écran disparaît).
    func stop() {
        lifecycleTask?.cancel()
        lifecycleTask = nil
        Task { await session.disconnect() }
    }
}
