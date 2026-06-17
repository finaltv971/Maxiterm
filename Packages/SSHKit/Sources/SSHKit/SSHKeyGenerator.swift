import Crypto
import Foundation

/// Génère des paires de clés SSH **Ed25519** et les sérialise au format OpenSSH
/// (clé privée non chiffrée + ligne `authorized_keys` publique). 100% Apple
/// (swift-crypto), aucune dépendance tierce.
public enum SSHKeyGenerator {
    /// Paire de clés générée, prête à stocker / partager.
    public struct GeneratedKey: Sendable {
        /// Clé privée au format `-----BEGIN OPENSSH PRIVATE KEY-----` (non chiffrée).
        public let privateKeyOpenSSH: String
        /// Ligne publique `ssh-ed25519 AAAA… commentaire` (format `authorized_keys`).
        public let publicKeyAuthorizedKey: String
        /// Empreinte SHA256 de la clé publique (`SHA256:…`).
        public let fingerprint: String
    }

    /// Crée une nouvelle clé Ed25519 aléatoire.
    public static func generateEd25519(comment: String = "") -> GeneratedKey {
        let privateKey = Curve25519.Signing.PrivateKey()
        let seed = Array(privateKey.rawRepresentation) // 32 octets
        let publicKey = Array(privateKey.publicKey.rawRepresentation) // 32 octets

        let publicBlob = sshString("ssh-ed25519") + sshString(publicKey)
        let publicBase64 = Data(publicBlob).base64EncodedString()
        let authorizedKey = comment.isEmpty
            ? "ssh-ed25519 \(publicBase64)"
            : "ssh-ed25519 \(publicBase64) \(comment)"

        let privatePEM = serializeOpenSSH(
            publicBlob: publicBlob,
            seed: seed,
            publicKey: publicKey,
            comment: comment
        )

        return GeneratedKey(
            privateKeyOpenSSH: privatePEM,
            publicKeyAuthorizedKey: authorizedKey,
            fingerprint: HostKeyFingerprint.sha256(forOpenSSHKey: authorizedKey)
        )
    }

    // MARK: - Sérialisation

    private static func serializeOpenSSH(
        publicBlob: [UInt8],
        seed: [UInt8],
        publicKey: [UInt8],
        comment: String
    ) -> String {
        let privateKeyBlob = seed + publicKey // 64 octets (graine + clé publique)
        let check = UInt32.random(in: UInt32.min ... UInt32.max)

        var privateSection = [UInt8]()
        privateSection += uint32(check)
        privateSection += uint32(check)
        privateSection += sshString("ssh-ed25519")
        privateSection += sshString(publicKey)
        privateSection += sshString(privateKeyBlob)
        privateSection += sshString(comment)
        // Bourrage 1, 2, 3… jusqu'à un multiple de 8 (taille de bloc du chiffre « none »).
        var pad: UInt8 = 1
        while privateSection.count % 8 != 0 {
            privateSection.append(pad)
            pad += 1
        }

        var blob = Array("openssh-key-v1\u{0}".utf8)
        blob += sshString("none") // ciphername
        blob += sshString("none") // kdfname
        blob += sshString([UInt8]()) // kdfoptions (vide)
        blob += uint32(1) // nombre de clés
        blob += sshString(publicBlob)
        blob += sshString(privateSection)

        let base64 = Data(blob).base64EncodedString()
        let wrapped = stride(from: 0, to: base64.count, by: 70).map { start -> String in
            let from = base64.index(base64.startIndex, offsetBy: start)
            let to = base64.index(from, offsetBy: 70, limitedBy: base64.endIndex) ?? base64.endIndex
            return String(base64[from ..< to])
        }
        return ([
            "-----BEGIN OPENSSH PRIVATE KEY-----",
        ] + wrapped + [
            "-----END OPENSSH PRIVATE KEY-----",
        ]).joined(separator: "\n")
    }

    private static func uint32(_ value: UInt32) -> [UInt8] {
        [UInt8((value >> 24) & 0xFF), UInt8((value >> 16) & 0xFF), UInt8((value >> 8) & 0xFF), UInt8(value & 0xFF)]
    }

    private static func sshString(_ bytes: [UInt8]) -> [UInt8] {
        uint32(UInt32(bytes.count)) + bytes
    }

    private static func sshString(_ text: String) -> [UInt8] {
        sshString(Array(text.utf8))
    }
}
