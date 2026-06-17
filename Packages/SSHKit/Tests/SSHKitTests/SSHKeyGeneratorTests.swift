import Foundation
import NIOSSH
import Testing
@testable import SSHKit

/// Vérifie que les clés générées sont valides : la clé privée OpenSSH se reparse
/// et redonne exactement la clé publique annoncée.
struct SSHKeyGeneratorTests {
    @Test func generatedKeyRoundTrips() throws {
        let generated = SSHKeyGenerator.generateEd25519(comment: "maxiterm@test")

        // La clé privée sérialisée se reparse sans erreur…
        let parsed = try OpenSSHPrivateKey.parse(pem: generated.privateKeyOpenSSH)
        // …et sa clé publique correspond à la ligne authorized_keys produite
        // (le commentaire est exclu de la comparaison).
        let expected = generated.publicKeyAuthorizedKey
            .split(separator: " ")
            .prefix(2)
            .joined(separator: " ")
        #expect(String(openSSHPublicKey: parsed.publicKey) == expected)
    }

    @Test func twoKeysDiffer() {
        let first = SSHKeyGenerator.generateEd25519()
        let second = SSHKeyGenerator.generateEd25519()
        #expect(first.publicKeyAuthorizedKey != second.publicKeyAuthorizedKey)
        #expect(first.fingerprint.hasPrefix("SHA256:"))
    }
}
