import Foundation
import NIOConcurrencyHelpers
import NIOCore
import NIOSSH

/// Delegate d'authentification par mot de passe.
///
/// N'offre le mot de passe qu'une seule fois : si le serveur le redemande
/// (rejet), on renvoie `nil`, ce qui fait échouer proprement l'authentification
/// plutôt que de boucler indéfiniment.
final class PasswordAuthDelegate: NIOSSHClientUserAuthenticationDelegate, Sendable {
    private let username: String
    private let password: String
    private let alreadyOffered = NIOLockedValueBox(false)

    init(username: String, password: String) {
        self.username = username
        self.password = password
    }

    func nextAuthenticationType(
        availableMethods: NIOSSHAvailableUserAuthenticationMethods,
        nextChallengePromise: EventLoopPromise<NIOSSHUserAuthenticationOffer?>
    ) {
        guard availableMethods.contains(.password) else {
            nextChallengePromise.succeed(nil)
            return
        }

        let offeredBefore = alreadyOffered.withLockedValue { offered -> Bool in
            defer { offered = true }
            return offered
        }
        guard !offeredBefore else {
            // Le mot de passe a déjà été proposé et rejeté.
            nextChallengePromise.succeed(nil)
            return
        }

        nextChallengePromise.succeed(
            NIOSSHUserAuthenticationOffer(
                username: username,
                serviceName: "",
                offer: .password(.init(password: password))
            )
        )
    }
}
