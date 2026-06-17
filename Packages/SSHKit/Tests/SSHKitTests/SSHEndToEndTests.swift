import Core
import Foundation
import Testing
@testable import SSHKit

/// Configuration d'un serveur SSH réel pour les tests bout-en-bout, lue depuis
/// l'environnement. Si `MAXITERM_SSH_E2E_KEY` est absent, les tests sont ignorés.
struct E2EConfig {
    let host: String
    let port: Int
    let username: String
    let privateKeyPEM: String

    static func fromEnvironment() -> E2EConfig? {
        let env = ProcessInfo.processInfo.environment
        guard
            let keyPath = env["MAXITERM_SSH_E2E_KEY"],
            let pem = try? String(contentsOfFile: keyPath, encoding: .utf8)
        else { return nil }
        return E2EConfig(
            host: env["MAXITERM_SSH_E2E_HOST"] ?? "127.0.0.1",
            port: Int(env["MAXITERM_SSH_E2E_PORT"] ?? "22") ?? 22,
            username: env["MAXITERM_SSH_E2E_USER"] ?? NSUserName(),
            privateKeyPEM: pem
        )
    }

    var host_: SSHHost {
        SSHHost(label: "e2e", hostname: host, port: port, username: username)
    }

    var credential: SSHCredential {
        .privateKeyPEM(privateKey: privateKeyPEM, passphrase: nil)
    }
}

/// Tests bout-en-bout contre un vrai serveur SSH (activés via variables d'env).
struct SSHEndToEndTests {
    @Test func connectsAndOpensDirectTCPIPTunnel() async throws {
        guard let config = E2EConfig.fromEnvironment() else { return } // ignoré si non configuré

        let connection = try await SSHRawConnection.connect(to: config.host_, credential: config.credential)
        // Tunnel direct-tcpip vers le même sshd : on doit recevoir sa bannière SSH.
        let channel = try await connection.openDirectTCPIP(targetHost: config.host, targetPort: config.port)
        var received = Data()
        for await chunk in channel.inbound {
            received.append(chunk)
            if received.count >= 4 { break }
        }
        await channel.close()
        await connection.close()

        let banner = String(decoding: received, as: UTF8.self)
        #expect(banner.hasPrefix("SSH-2.0") || banner.hasPrefix("SSH-1."))
    }

    @Test func localPortForwardingRelaysTraffic() async throws {
        guard let config = E2EConfig.fromEnvironment() else { return } // ignoré si non configuré

        let connection = try await SSHRawConnection.connect(to: config.host_, credential: config.credential)
        // Écoute sur un port local éphémère, relayé vers le sshd cible.
        let forward = try await connection.startLocalForward(
            localPort: 0,
            remoteHost: config.host,
            remotePort: config.port
        )
        let port = forward.localPort
        #expect(port > 0)

        // Une connexion TCP au port local doit recevoir la bannière SSH du serveur.
        let banner = try readBanner(host: "127.0.0.1", port: port)
        #expect(banner.hasPrefix("SSH-2.0") || banner.hasPrefix("SSH-1."))

        await forward.stop()
        await connection.close()
    }

    /// Lit les premiers octets d'un service TCP via un socket POSIX brut (sans NIO).
    private func readBanner(host: String, port: Int) throws -> String {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        #expect(fd >= 0)
        defer { Foundation.close(fd) }
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(port).bigEndian
        inet_pton(AF_INET, host, &addr.sin_addr)
        let connectResult = withUnsafePointer(to: &addr) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                Foundation.connect(fd, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        #expect(connectResult == 0)
        var buffer = [UInt8](repeating: 0, count: 64)
        let count = read(fd, &buffer, buffer.count)
        return String(decoding: buffer.prefix(max(0, count)), as: UTF8.self)
    }

    @Test func connectsThroughJumpHost() async throws {
        guard let config = E2EConfig.fromEnvironment() else { return } // ignoré si non configuré

        // Le même sshd sert de jump host ET de cible (ProxyJump localhost→localhost).
        let connection = try await SSHRawConnection.connectThroughJump(
            jump: SSHJumpConfig(host: config.host_, credential: config.credential),
            target: config.host_,
            targetCredential: config.credential,
            targetKnownHostKey: nil
        )
        // Ouvre un tunnel depuis la session cible : on doit obtenir la bannière SSH,
        // ce qui prouve que le handshake imbriqué de la cible a réussi.
        let channel = try await connection.openDirectTCPIP(targetHost: config.host, targetPort: config.port)
        var received = Data()
        for await chunk in channel.inbound {
            received.append(chunk)
            if received.count >= 4 { break }
        }
        await channel.close()
        await connection.close()

        let banner = String(decoding: received, as: UTF8.self)
        #expect(banner.hasPrefix("SSH-2.0") || banner.hasPrefix("SSH-1."))
    }

    @Test func interactiveShellThroughJumpHost() async throws {
        guard let config = E2EConfig.fromEnvironment() else { return } // ignoré si non configuré

        let session = SSHSession()
        let jump = SSHJumpConfig(host: config.host_, credential: config.credential)
        try await session.connect(to: config.host_, credential: config.credential, jump: jump)

        // Envoie une commande et attend de revoir son marqueur dans la sortie.
        let marker = "MAXITERM_JUMP_\(UInt32.random(in: 0 ... .max))"
        await session.send(Data("echo \(marker)\n".utf8))

        var seen = ""
        var chunks = 0
        for await chunk in await session.terminalOutput {
            seen += String(decoding: chunk, as: UTF8.self)
            chunks += 1
            if seen.contains(marker) || chunks > 200 { break }
        }
        await session.disconnect()
        #expect(seen.contains(marker))
    }
}
