import Crypto
import Foundation
import NIOCore
import NIOEmbedded
import NIOSSH
import Testing
@testable import SSHKit

struct TOFUHostKeyVerifierTests {
    // Clé publique Ed25519 JETABLE (test only).
    private let publicKey =
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEZuMvKSn4MhO8usog4uwcVlqztlwemL4NJiRaW/ofWI test"
    private let expectedFingerprint = "SHA256:Wg1O+isqtlVSgGNQlaaYjDVH0NWaHsQZQnd27BZGHHw"

    @Test func fingerprintMatchesOpenSSH() {
        #expect(HostKeyFingerprint.sha256(forOpenSSHKey: publicKey) == expectedFingerprint)
    }

    @Test func unknownKeyIsLearnedAndAccepted() throws {
        let loop = EmbeddedEventLoop()
        let key = try NIOSSHPublicKey(openSSHPublicKey: publicKey)
        let verifier = TOFUHostKeyVerifier(knownKey: nil)
        verifier.validateHostKey(hostKey: key, validationCompletePromise: loop.makePromise(of: Void.self))

        if case .learned = verifier.resolvedOutcome {} else {
            Issue.record("Une clé inconnue doit être apprise (TOFU).")
        }
    }

    @Test func sameKeyIsAccepted() throws {
        let loop = EmbeddedEventLoop()
        let key = try NIOSSHPublicKey(openSSHPublicKey: publicKey)
        let stored = String(openSSHPublicKey: key)
        let verifier = TOFUHostKeyVerifier(knownKey: stored)
        verifier.validateHostKey(hostKey: key, validationCompletePromise: loop.makePromise(of: Void.self))

        if case .unchanged = verifier.resolvedOutcome {} else {
            Issue.record("Une clé identique doit être acceptée sans changement.")
        }
    }

    @Test func changedKeyIsRejected() throws {
        let loop = EmbeddedEventLoop()
        let key = try NIOSSHPublicKey(openSSHPublicKey: publicKey)
        let verifier = TOFUHostKeyVerifier(knownKey: "ssh-ed25519 DIFFERENT_STORED_KEY other")
        let promise = loop.makePromise(of: Void.self)

        var rejected = false
        promise.futureResult.whenFailure { _ in rejected = true }
        verifier.validateHostKey(hostKey: key, validationCompletePromise: promise)
        loop.run()

        #expect(rejected)
        if case .learned = verifier.resolvedOutcome {
            Issue.record("Une clé modifiée ne doit pas être mémorisée.")
        }
    }
}
