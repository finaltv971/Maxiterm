import NIOCore
import NIOSSH

/// Valide la clé hôte présentée par le serveur.
///
/// > ⚠️ Limitation MVP : `AcceptAllHostKeysDelegate` accepte **toute** clé hôte,
/// > ce qui expose à une attaque de l'homme du milieu. C'est une limitation
/// > connue et documentée (voir SECURITY.md). Le jalon suivant introduit une
/// > validation TOFU (Trust On First Use) avec épinglage persistant.
final class AcceptAllHostKeysDelegate: NIOSSHClientServerAuthenticationDelegate, Sendable {
    func validateHostKey(hostKey: NIOSSHPublicKey, validationCompletePromise: EventLoopPromise<Void>) {
        validationCompletePromise.succeed(())
    }
}
