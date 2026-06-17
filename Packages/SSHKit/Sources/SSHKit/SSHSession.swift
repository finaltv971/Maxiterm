import Core
import Foundation
import NIOCore
import NIOPosix
import NIOSSH

/// Session SSH interactive bâtie directement sur `swift-nio-ssh` (Apple) :
/// connecte un ``SSHHost``, ouvre un canal session avec PTY + shell, et expose
/// la sortie distante via un `AsyncStream<Data>` tout en acceptant la saisie.
///
/// `actor` : l'état (canaux racine/enfant) est sérialisé. La sortie réseau est
/// poussée dans le flux via la continuation de l'`AsyncStream`, qui est
/// `Sendable` et peut donc être alimentée depuis la boucle d'évènements NIO.
public actor SSHSession {
    public enum State: Equatable, Sendable {
        case idle
        case connecting
        case connected
        case closed
        case failed(String)
    }

    private let group: EventLoopGroup
    private var rootChannel: Channel?
    private var childChannel: Channel?

    private let output: AsyncStream<Data>
    private let outputContinuation: AsyncStream<Data>.Continuation

    public private(set) var state: State = .idle

    public init() {
        self.group = MultiThreadedEventLoopGroup.singleton
        var continuation: AsyncStream<Data>.Continuation!
        self.output = AsyncStream(bufferingPolicy: .unbounded) { continuation = $0 }
        self.outputContinuation = continuation
    }

    /// Flux de sortie du terminal distant (stdout + stderr fusionnés).
    public var terminalOutput: AsyncStream<Data> { output }

    // MARK: - Cycle de vie

    private var hostKeyVerifier: TOFUHostKeyVerifier?

    public func connect(
        to host: SSHHost,
        credential: SSHCredential,
        cols: Int = 80,
        rows: Int = 24,
        knownHostKey: String? = nil,
        jump: SSHJumpConfig? = nil
    ) async throws {
        let validationErrors = host.validationErrors()
        guard validationErrors.isEmpty else {
            throw SSHConnectionError.invalidHost(reason: validationErrors.joined(separator: " "))
        }

        state = .connecting
        let continuation = outputContinuation
        let verifier = TOFUHostKeyVerifier(knownKey: knownHostKey)
        hostKeyVerifier = verifier

        do {
            let root: Channel
            if let jump {
                root = try await connectSSHRootThroughJump(
                    jump: jump,
                    target: host,
                    targetCredential: credential,
                    targetValidator: verifier,
                    group: group
                )
            } else {
                root = try await connectSSHRoot(
                    host: host,
                    credential: credential,
                    group: group,
                    hostKeyValidator: verifier
                )
            }
            rootChannel = root
            childChannel = try await openShellChannel(on: root, cols: cols, rows: rows, continuation: continuation)
            state = .connected
        } catch let error as SSHConnectionError {
            state = .failed(error.localizedDescription)
            throw error
        } catch {
            await teardown()
            state = .failed(error.localizedDescription)
            throw SSHConnectionError.connectionFailed(underlying: String(describing: error))
        }
    }

    /// Clé hôte apprise lors d'une première connexion (TOFU), à persister.
    /// `nil` si la clé était déjà connue.
    public func learnedHostKey() -> String? {
        if case let .learned(key) = hostKeyVerifier?.resolvedOutcome { return key }
        return nil
    }

    /// Envoie des octets bruts (frappes clavier) vers le shell distant.
    public func send(_ data: Data) async {
        guard let childChannel else { return }
        var buffer = childChannel.allocator.buffer(capacity: data.count)
        buffer.writeBytes(data)
        try? await childChannel.writeAndFlush(buffer).get()
    }

    /// Notifie le serveur d'un changement de dimensions du terminal.
    public func resize(cols: Int, rows: Int) async {
        guard let childChannel else { return }
        let event = SSHChannelRequestEvent.WindowChangeRequest(
            terminalCharacterWidth: cols,
            terminalRowHeight: rows,
            terminalPixelWidth: 0,
            terminalPixelHeight: 0
        )
        try? await childChannel.triggerUserOutboundEvent(event).get()
    }

    /// Ferme proprement le canal et la connexion.
    public func disconnect() async {
        await teardown()
        if state == .connected { state = .closed }
        outputContinuation.finish()
    }

    // MARK: - Détails privés

    private func teardown() async {
        try? await childChannel?.close().get()
        try? await rootChannel?.close().get()
        childChannel = nil
        rootChannel = nil
    }

    private func openShellChannel(
        on root: Channel,
        cols: Int,
        rows: Int,
        continuation: AsyncStream<Data>.Continuation
    ) async throws -> Channel {
        try await root.eventLoop.flatSubmit {
            root.pipeline.handler(type: NIOSSHHandler.self).flatMap { sshHandler in
                let promise = root.eventLoop.makePromise(of: Channel.self)
                sshHandler.createChannel(promise, channelType: .session) { childChannel, channelType in
                    guard channelType == .session else {
                        return childChannel.eventLoop.makeFailedFuture(
                            SSHConnectionError.connectionFailed(underlying: "Type de canal inattendu.")
                        )
                    }
                    return childChannel.eventLoop.makeCompletedFuture {
                        let handler = PTYChannelHandler(
                            cols: cols,
                            rows: rows,
                            onOutput: { data in continuation.yield(data) },
                            onClose: { _ in continuation.finish() }
                        )
                        try childChannel.pipeline.syncOperations.addHandler(handler)
                    }
                }
                return promise.futureResult
            }
        }.get()
    }
}
