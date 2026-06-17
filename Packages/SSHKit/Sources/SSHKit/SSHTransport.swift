import Core
import Foundation
import NIOCore
import NIOPosix
import NIOSSH

/// Décrit un **jump host** (ProxyJump) intermédiaire : la connexion vers la cible
/// passe par lui.
public struct SSHJumpConfig: Sendable {
    public let host: SSHHost
    public let credential: SSHCredential
    public let knownHostKey: String?

    public init(host: SSHHost, credential: SSHCredential, knownHostKey: String? = nil) {
        self.host = host
        self.credential = credential
        self.knownHostKey = knownHostKey
    }
}

/// Construit le delegate d'authentification adapté à l'identifiant fourni.
/// Partagé entre la session terminal (``SSHSession``) et la connexion brute
/// pour SFTP (``SSHRawConnection``).
func makeAuthenticationDelegate(
    username: String,
    credential: SSHCredential
) throws -> NIOSSHClientUserAuthenticationDelegate {
    switch credential {
    case let .password(password):
        return PasswordAuthDelegate(username: username, password: password)
    case let .privateKeyPEM(privateKey, passphrase):
        do {
            let key = try OpenSSHPrivateKey.parse(pem: privateKey, passphrase: passphrase)
            return KeyAuthDelegate(username: username, privateKey: key)
        } catch {
            throw SSHConnectionError.connectionFailed(underlying: error.localizedDescription)
        }
    }
}

/// Établit la couche transport SSH (TCP + handshake + authentification) et
/// retourne le canal racine portant le `NIOSSHHandler`.
func connectSSHRoot(
    host: SSHHost,
    credential: SSHCredential,
    group: EventLoopGroup,
    hostKeyValidator: NIOSSHClientServerAuthenticationDelegate
) async throws -> Channel {
    let validationErrors = host.validationErrors()
    guard validationErrors.isEmpty else {
        throw SSHConnectionError.invalidHost(reason: validationErrors.joined(separator: " "))
    }

    let authentication = try makeAuthenticationDelegate(username: host.username, credential: credential)

    let bootstrap = ClientBootstrap(group: group)
        .channelInitializer { channel in
            channel.eventLoop.makeCompletedFuture {
                let handler = NIOSSHHandler(
                    role: .client(.init(
                        userAuthDelegate: authentication,
                        serverAuthDelegate: hostKeyValidator
                    )),
                    allocator: channel.allocator,
                    inboundChildChannelInitializer: nil
                )
                try channel.pipeline.syncOperations.addHandler(handler)
            }
        }
        .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
        .channelOption(ChannelOptions.socket(SocketOptionLevel(IPPROTO_TCP), TCP_NODELAY), value: 1)

    return try await bootstrap.connect(host: host.hostname, port: host.port).get()
}

/// Établit la couche transport SSH vers `target` **à travers un jump host** :
/// la session SSH cible est tunnelisée dans un canal `direct-tcpip` ouvert sur le
/// jump. Retourne le canal **enfant** portant le `NIOSSHHandler` de la cible
/// (utilisable comme un canal racine pour ouvrir des sessions/sous-systèmes).
func connectSSHRootThroughJump(
    jump: SSHJumpConfig,
    target: SSHHost,
    targetCredential: SSHCredential,
    targetValidator: NIOSSHClientServerAuthenticationDelegate,
    group: EventLoopGroup
) async throws -> Channel {
    let targetErrors = target.validationErrors()
    guard targetErrors.isEmpty else {
        throw SSHConnectionError.invalidHost(reason: targetErrors.joined(separator: " "))
    }

    let jumpRoot = try await connectSSHRoot(
        host: jump.host,
        credential: jump.credential,
        group: group,
        hostKeyValidator: TOFUHostKeyVerifier(knownKey: jump.knownHostKey)
    )

    let targetAuth = try makeAuthenticationDelegate(username: target.username, credential: targetCredential)
    let origin = try SocketAddress(ipAddress: "127.0.0.1", port: 0)
    let channelType = SSHChannelType.directTCPIP(
        SSHChannelType.DirectTCPIP(
            targetHost: target.hostname,
            targetPort: target.port,
            originatorAddress: origin
        )
    )

    return try await jumpRoot.eventLoop.flatSubmit {
        jumpRoot.pipeline.handler(type: NIOSSHHandler.self).flatMap { jumpHandler in
            let promise = jumpRoot.eventLoop.makePromise(of: Channel.self)
            jumpHandler.createChannel(promise, channelType: channelType) { child, _ in
                child.eventLoop.makeCompletedFuture {
                    let targetHandler = NIOSSHHandler(
                        role: .client(.init(
                            userAuthDelegate: targetAuth,
                            serverAuthDelegate: targetValidator
                        )),
                        allocator: child.allocator,
                        inboundChildChannelInitializer: nil
                    )
                    try child.pipeline.syncOperations.addHandlers([
                        SSHChannelDataUnwrapper(),
                        targetHandler,
                    ])
                }
            }
            return promise.futureResult
        }
    }.get()
}
