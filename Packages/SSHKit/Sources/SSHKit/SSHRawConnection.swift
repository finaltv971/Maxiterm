import Core
import Foundation
import NIOCore
import NIOPosix
import NIOSSH

/// Connexion SSH brute, indépendante de la session terminal, destinée à ouvrir
/// des canaux de sous-système (ex. `sftp`). Réutilise la couche transport
/// partagée (``connectSSHRoot``).
public actor SSHRawConnection {
    private let group: EventLoopGroup
    private let root: Channel
    private let learnedKey: String?
    private let verifier: TOFUHostKeyVerifier?

    private init(group: EventLoopGroup, root: Channel, learnedKey: String?, verifier: TOFUHostKeyVerifier? = nil) {
        self.group = group
        self.root = root
        self.learnedKey = learnedKey
        self.verifier = verifier
    }

    /// Établit une nouvelle connexion SSH authentifiée, avec validation TOFU
    /// de la clé hôte.
    public static func connect(
        to host: SSHHost,
        credential: SSHCredential,
        knownHostKey: String? = nil
    ) async throws -> SSHRawConnection {
        let group = MultiThreadedEventLoopGroup.singleton
        let verifier = TOFUHostKeyVerifier(knownKey: knownHostKey)
        do {
            let root = try await connectSSHRoot(
                host: host,
                credential: credential,
                group: group,
                hostKeyValidator: verifier
            )
            let learned: String?
            if case let .learned(key) = verifier.resolvedOutcome { learned = key } else { learned = nil }
            return SSHRawConnection(group: group, root: root, learnedKey: learned)
        } catch let error as SSHConnectionError {
            throw error
        } catch {
            throw SSHConnectionError.connectionFailed(underlying: String(describing: error))
        }
    }

    /// Établit une connexion vers `target` **à travers un jump host** (ProxyJump) :
    /// la session SSH cible est tunnelisée dans un canal `direct-tcpip` ouvert sur
    /// le jump. Chaque saut a sa propre authentification et validation TOFU.
    public static func connectThroughJump(
        jump: SSHJumpConfig,
        target: SSHHost,
        targetCredential: SSHCredential,
        targetKnownHostKey: String?
    ) async throws -> SSHRawConnection {
        let group = MultiThreadedEventLoopGroup.singleton
        do {
            let targetVerifier = TOFUHostKeyVerifier(knownKey: targetKnownHostKey)
            let childChannel = try await connectSSHRootThroughJump(
                jump: jump,
                target: target,
                targetCredential: targetCredential,
                targetValidator: targetVerifier,
                group: group
            )
            // La connexion retournée pilote la session SSH **cible** (canal enfant).
            return SSHRawConnection(group: group, root: childChannel, learnedKey: nil, verifier: targetVerifier)
        } catch let error as SSHConnectionError {
            throw error
        } catch {
            throw SSHConnectionError.connectionFailed(underlying: String(describing: error))
        }
    }

    /// Clé hôte apprise lors d'une première connexion (TOFU), ou `nil`.
    public func learnedHostKey() -> String? {
        if let learnedKey { return learnedKey }
        if let verifier, case let .learned(key) = verifier.resolvedOutcome { return key }
        return nil
    }

    /// Ouvre un canal de session demandant le sous-système indiqué et retourne
    /// un canal d'octets prêt à l'emploi.
    public func openSubsystem(_ name: String) async throws -> SSHByteChannel {
        var continuationHolder: AsyncStream<Data>.Continuation!
        let stream = AsyncStream<Data>(bufferingPolicy: .unbounded) { continuationHolder = $0 }
        let continuation = continuationHolder!

        let root = self.root
        let channel = try await root.eventLoop.flatSubmit {
            root.pipeline.handler(type: NIOSSHHandler.self).flatMap { sshHandler in
                let promise = root.eventLoop.makePromise(of: Channel.self)
                sshHandler.createChannel(promise, channelType: .session) { child, channelType in
                    guard channelType == .session else {
                        return child.eventLoop.makeFailedFuture(
                            SSHConnectionError.connectionFailed(underlying: "Type de canal inattendu.")
                        )
                    }
                    return child.eventLoop.makeCompletedFuture {
                        let handler = SubsystemChannelHandler(
                            subsystem: name,
                            onData: { continuation.yield($0) },
                            onClose: { _ in continuation.finish() }
                        )
                        try child.pipeline.syncOperations.addHandler(handler)
                    }
                }
                return promise.futureResult
            }
        }.get()

        return SSHByteChannel(channel: channel, inbound: stream, continuation: continuation)
    }

    /// Ouvre un canal **`direct-tcpip`** vers `targetHost:targetPort` à travers
    /// cette connexion SSH, et retourne un canal d'octets. Base du port forwarding
    /// et des jump hosts.
    public func openDirectTCPIP(targetHost: String, targetPort: Int) async throws -> SSHByteChannel {
        var continuationHolder: AsyncStream<Data>.Continuation!
        let stream = AsyncStream<Data>(bufferingPolicy: .unbounded) { continuationHolder = $0 }
        let continuation = continuationHolder!

        let origin = try SocketAddress(ipAddress: "127.0.0.1", port: 0)
        let channelType = SSHChannelType.directTCPIP(
            SSHChannelType.DirectTCPIP(
                targetHost: targetHost,
                targetPort: targetPort,
                originatorAddress: origin
            )
        )

        let root = self.root
        let channel = try await root.eventLoop.flatSubmit {
            root.pipeline.handler(type: NIOSSHHandler.self).flatMap { sshHandler in
                let promise = root.eventLoop.makePromise(of: Channel.self)
                sshHandler.createChannel(promise, channelType: channelType) { child, _ in
                    child.eventLoop.makeCompletedFuture {
                        let handler = DirectTCPIPChannelHandler(
                            onData: { continuation.yield($0) },
                            onClose: { _ in continuation.finish() }
                        )
                        try child.pipeline.syncOperations.addHandler(handler)
                    }
                }
                return promise.futureResult
            }
        }.get()

        return SSHByteChannel(channel: channel, inbound: stream, continuation: continuation)
    }

    /// Démarre un **port forwarding local** : écoute sur `localHost:localPort` et
    /// relaie chaque connexion vers `remoteHost:remotePort` via un canal
    /// `direct-tcpip` sur cette connexion SSH. Retourne un handle pour l'arrêter.
    public func startLocalForward(
        localHost: String = "127.0.0.1",
        localPort: Int,
        remoteHost: String,
        remotePort: Int
    ) async throws -> LocalForward {
        let root = self.root

        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .childChannelInitializer { localChannel in
                Self.bridge(
                    localChannel: localChannel,
                    root: root,
                    remoteHost: remoteHost,
                    remotePort: remotePort
                )
            }

        let serverChannel = try await bootstrap.bind(host: localHost, port: localPort).get()
        return LocalForward(serverChannel: serverChannel)
    }

    /// Construit le pont bidirectionnel entre un socket local accepté et un canal
    /// `direct-tcpip` ouvert vers la cible.
    private static func bridge(
        localChannel: Channel,
        root: Channel,
        remoteHost: String,
        remotePort: Int
    ) -> EventLoopFuture<Void> {
        let glueLocal = GlueHandler()
        let glueRemote = GlueHandler()

        let origin = (try? SocketAddress(ipAddress: "127.0.0.1", port: 0))
            ?? localChannel.localAddress!
        let channelType = SSHChannelType.directTCPIP(
            SSHChannelType.DirectTCPIP(targetHost: remoteHost, targetPort: remotePort, originatorAddress: origin)
        )

        let childFuture: EventLoopFuture<Channel> = root.eventLoop.flatSubmit {
            root.pipeline.handler(type: NIOSSHHandler.self).flatMap { sshHandler in
                let promise = root.eventLoop.makePromise(of: Channel.self)
                sshHandler.createChannel(promise, channelType: channelType) { child, _ in
                    child.eventLoop.makeCompletedFuture {
                        try child.pipeline.syncOperations.addHandlers([SSHChannelDataUnwrapper(), glueRemote])
                    }
                }
                return promise.futureResult
            }
        }

        return childFuture.flatMap { sshChild in
            let wireLocal = localChannel.pipeline.addHandler(glueLocal).map { glueLocal.setPeer(sshChild) }
            let wireRemote = sshChild.eventLoop.submit { glueRemote.setPeer(localChannel) }
            return wireLocal.and(wireRemote).map { _ in }
        }
    }

    public func close() async {
        try? await root.close().get()
    }
}

/// Handle d'un port forwarding local actif.
public final class LocalForward: @unchecked Sendable {
    private let serverChannel: Channel

    init(serverChannel: Channel) {
        self.serverChannel = serverChannel
    }

    /// Port effectivement attribué (utile si `localPort` valait 0).
    public var localPort: Int { serverChannel.localAddress?.port ?? 0 }

    public func stop() async {
        try? await serverChannel.close().get()
    }
}
