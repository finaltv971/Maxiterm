import Core
import Foundation
import Testing
@testable import SFTPKit

/// Tests SFTP bout-en-bout contre un vrai serveur (activés via `MAXITERM_SSH_E2E_KEY`).
struct SFTPEndToEndTests {
    private struct Config {
        let host: String
        let port: Int
        let username: String
        let pem: String

        static func fromEnvironment() -> Config? {
            let env = ProcessInfo.processInfo.environment
            guard
                let keyPath = env["MAXITERM_SSH_E2E_KEY"],
                let pem = try? String(contentsOfFile: keyPath, encoding: .utf8)
            else { return nil }
            return Config(
                host: env["MAXITERM_SSH_E2E_HOST"] ?? "127.0.0.1",
                port: Int(env["MAXITERM_SSH_E2E_PORT"] ?? "22") ?? 22,
                username: env["MAXITERM_SSH_E2E_USER"] ?? NSUserName(),
                pem: pem
            )
        }
    }

    @Test func uploadDownloadChmodRoundTrip() async throws {
        guard let config = Config.fromEnvironment() else { return } // ignoré si non configuré

        let host = SSHHost(label: "e2e", hostname: config.host, port: config.port, username: config.username)
        let client = try await SFTPClient.connect(
            to: host,
            credential: .privateKeyPEM(privateKey: config.pem, passphrase: nil)
        )

        let home = try await client.realPath(".")
        let remoteName = "maxiterm-e2e-\(UInt32.random(in: 0 ... .max)).txt"
        let remotePath = home.hasSuffix("/") ? home + remoteName : home + "/" + remoteName

        // Prépare un fichier local source.
        let payload = Data("MaxiTerm SFTP e2e — \(remoteName)".utf8)
        let localUp = FileManager.default.temporaryDirectory.appendingPathComponent(remoteName)
        try payload.write(to: localUp)

        // Envoi en streaming.
        try await client.uploadFile(from: localUp, to: remotePath)

        // chmod 600 puis vérification via stat.
        try await client.setPermissions(0o600, at: remotePath)
        let attributes = try await client.stat(remotePath)
        #expect((attributes.permissions ?? 0) & 0o777 == 0o600)

        // Téléchargement en streaming, contenu identique.
        let localDown = FileManager.default.temporaryDirectory.appendingPathComponent("dl-" + remoteName)
        try? FileManager.default.removeItem(at: localDown)
        try await client.downloadFile(at: remotePath, to: localDown)
        let roundTripped = try Data(contentsOf: localDown)
        #expect(roundTripped == payload)

        // Nettoyage.
        try await client.removeFile(remotePath)
        await client.disconnect()
        try? FileManager.default.removeItem(at: localUp)
        try? FileManager.default.removeItem(at: localDown)
    }
}
