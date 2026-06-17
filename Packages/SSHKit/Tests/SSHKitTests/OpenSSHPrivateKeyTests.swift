import Foundation
import NIOSSH
import Testing
@testable import SSHKit

/// Vérifie le parsing en générant des clés JETABLES à la volée via `ssh-keygen`
/// (aucune clé embarquée) et en comparant la clé publique dérivée à l'oracle.
struct OpenSSHPrivateKeyTests {
    #if os(macOS)
    private func assertRoundTrip(type: String, bits: Int? = nil) throws {
        guard let pair = SSHKeygenFixture.generate(type: type, bits: bits) else { return } // ssh-keygen absent
        let key = try OpenSSHPrivateKey.parse(pem: pair.privatePEM)
        #expect(String(openSSHPublicKey: key.publicKey) == pair.publicLine)
    }

    @Test func parsesEd25519() throws {
        try assertRoundTrip(type: "ed25519")
    }

    @Test func parsesECDSAp256() throws {
        try assertRoundTrip(type: "ecdsa", bits: 256)
    }

    @Test func parsesECDSAp384() throws {
        try assertRoundTrip(type: "ecdsa", bits: 384)
    }

    @Test func parsesECDSAp521() throws {
        try assertRoundTrip(type: "ecdsa", bits: 521)
    }
    #endif

    @Test func rejectsNonOpenSSHContent() {
        #expect(throws: OpenSSHKeyError.self) {
            try OpenSSHPrivateKey.parse(pem: "pas une clé")
        }
    }
}
