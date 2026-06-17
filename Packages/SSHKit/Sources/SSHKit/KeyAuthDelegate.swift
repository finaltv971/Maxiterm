import Foundation
import NIOConcurrencyHelpers
import NIOCore
import NIOSSH

/// Delegate d'authentification par clé publique (Ed25519 / ECDSA).
///
/// N'offre la clé qu'une fois : si le serveur la rejette, on renvoie `nil` pour
/// faire échouer proprement l'authentification.
final class KeyAuthDelegate: NIOSSHClientUserAuthenticationDelegate, Sendable {
    private let username: String
    private let privateKey: NIOSSHPrivateKey
    private let alreadyOffered = NIOLockedValueBox(false)

    init(username: String, privateKey: NIOSSHPrivateKey) {
        self.username = username
        self.privateKey = privateKey
    }

    func nextAuthenticationType(
        availableMethods: NIOSSHAvailableUserAuthenticationMethods,
        nextChallengePromise: EventLoopPromise<NIOSSHUserAuthenticationOffer?>
    ) {
        guard availableMethods.contains(.publicKey) else {
            nextChallengePromise.succeed(nil)
            return
        }

        let offeredBefore = alreadyOffered.withLockedValue { offered -> Bool in
            defer { offered = true }
            return offered
        }
        guard !offeredBefore else {
            nextChallengePromise.succeed(nil)
            return
        }

        nextChallengePromise.succeed(
            NIOSSHUserAuthenticationOffer(
                username: username,
                serviceName: "",
                offer: .privateKey(.init(privateKey: privateKey))
            )
        )
    }
}
