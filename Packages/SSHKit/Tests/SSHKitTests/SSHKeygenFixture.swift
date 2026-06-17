import Foundation

#if os(macOS)

/// Génère des paires de clés **à la volée** via `ssh-keygen` (dans un dossier
/// temporaire) pour servir d'oracles aux tests de parsing/déchiffrement.
///
/// Aucune clé n'est donc embarquée dans les sources — rien à committer ni à
/// exposer. Les tests qui s'en servent sont ignorés si `ssh-keygen` est absent.
enum SSHKeygenFixture {
    struct KeyPair {
        let privatePEM: String
        /// Ligne publique réduite à « type base64 » (sans commentaire).
        let publicLine: String
    }

    static func generate(type: String, bits: Int? = nil, passphrase: String = "") -> KeyPair? {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("maxiterm-keygen-\(UUID().uuidString)")
        guard (try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)) != nil
        else { return nil }
        defer { try? FileManager.default.removeItem(at: directory) }

        let keyPath = directory.appendingPathComponent("id")
        var arguments = ["-t", type, "-N", passphrase, "-C", "maxiterm-test", "-f", keyPath.path, "-q"]
        if let bits { arguments += ["-b", String(bits)] }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh-keygen")
        process.arguments = arguments
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil // ssh-keygen indisponible -> test ignoré
        }
        guard
            process.terminationStatus == 0,
            let privatePEM = try? String(contentsOf: keyPath, encoding: .utf8),
            let publicRaw = try? String(
                contentsOf: directory.appendingPathComponent("id.pub"), encoding: .utf8
            )
        else { return nil }

        let publicLine = publicRaw.split(separator: " ").prefix(2).joined(separator: " ")
        return KeyPair(privatePEM: privatePEM, publicLine: publicLine)
    }
}

#endif
