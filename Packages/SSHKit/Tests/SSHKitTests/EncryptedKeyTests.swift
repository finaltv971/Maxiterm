import Foundation
import NIOSSH
import Testing
@testable import SSHKit

/// Vérifie la chaîne de déchiffrement des clés OpenSSH protégées par phrase de
/// passe : constantes Blowfish (générées via π), cœur Blowfish, et déchiffrement
/// bout-en-bout de clés **générées à la volée** par `ssh-keygen` (rien embarqué).
struct EncryptedKeyTests {
    // MARK: - Constantes Blowfish générées à partir de π

    @Test func blowfishInitialConstantsMatchKnownAnchors() {
        let constants = BlowfishConstants.shared
        // Ancrages publics et bien connus du tableau P et des boîtes-S.
        #expect(constants.p[0] == 0x243F_6A88)
        #expect(constants.p[1] == 0x85A3_08D3)
        #expect(constants.p[17] == 0x8979_FB1B)
        #expect(constants.s[0] == 0xD131_0BA6)
        #expect(constants.s[1] == 0x98DF_B5AC)
        #expect(constants.s[1023] == 0x3AC3_72E6) // S3[255], dernière constante
    }

    // MARK: - Vecteur de test Blowfish ECB (Eric Young)

    @Test func blowfishECBKnownAnswer() {
        var state = BlowfishState()
        state.expand0(key: [0, 0, 0, 0, 0, 0, 0, 0])
        var left: UInt32 = 0
        var right: UInt32 = 0
        state.encipher(&left, &right)
        #expect(left == 0x4EF9_9745)
        #expect(right == 0x6198_DD78)
    }

    // MARK: - Déchiffrement bout-en-bout (clés générées à la volée)

    #if os(macOS)
    private static let passphrase = "maxiterm-test"

    @Test func decryptsEncryptedEd25519() throws {
        guard let pair = SSHKeygenFixture.generate(type: "ed25519", passphrase: Self.passphrase) else { return }
        let key = try OpenSSHPrivateKey.parse(pem: pair.privatePEM, passphrase: Self.passphrase)
        #expect(String(openSSHPublicKey: key.publicKey) == pair.publicLine)
    }

    @Test func decryptsEncryptedECDSA() throws {
        guard let pair = SSHKeygenFixture.generate(type: "ecdsa", bits: 256, passphrase: Self.passphrase) else {
            return
        }
        let key = try OpenSSHPrivateKey.parse(pem: pair.privatePEM, passphrase: Self.passphrase)
        #expect(String(openSSHPublicKey: key.publicKey) == pair.publicLine)
    }

    @Test func wrongPassphraseIsRejected() throws {
        guard let pair = SSHKeygenFixture.generate(type: "ed25519", passphrase: Self.passphrase) else { return }
        #expect(throws: OpenSSHKeyError.wrongPassphrase) {
            try OpenSSHPrivateKey.parse(pem: pair.privatePEM, passphrase: "mauvaise")
        }
    }

    @Test func missingPassphraseIsReported() throws {
        guard let pair = SSHKeygenFixture.generate(type: "ed25519", passphrase: Self.passphrase) else { return }
        #expect(throws: OpenSSHKeyError.encryptedKeyNeedsPassphrase) {
            try OpenSSHPrivateKey.parse(pem: pair.privatePEM)
        }
    }
    #endif
}
