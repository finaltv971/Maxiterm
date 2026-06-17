import Crypto
import Foundation
import NIOConcurrencyHelpers
import NIOCore
import NIOSSH

/// Calcule l'empreinte SHA256 d'une clé hôte OpenSSH (format `SHA256:base64`).
public enum HostKeyFingerprint {
    public static func sha256(forOpenSSHKey openSSHKey: String) -> String {
        let parts = openSSHKey.split(separator: " ")
        guard parts.count >= 2, let blob = Data(base64Encoded: String(parts[1])) else {
            return "empreinte indisponible"
        }
        let digest = SHA256.hash(data: blob)
        let encoded = Data(digest).base64EncodedString().replacingOccurrences(of: "=", with: "")
        return "SHA256:" + encoded
    }
}

/// Validateur de clé hôte en **TOFU** (Trust On First Use).
///
/// - Clé inconnue → acceptée et mémorisée (première connexion).
/// - Clé connue identique → acceptée.
/// - Clé connue **différente** → refusée (possible attaque MITM).
///
/// Le validateur s'exécute sur la boucle d'évènements : il ne fait **aucune**
/// I/O. Le résultat (clé apprise) est récupéré après la connexion via
/// ``resolvedOutcome`` et persisté par l'appelant.
public final class TOFUHostKeyVerifier: NIOSSHClientServerAuthenticationDelegate, Sendable {
    public enum Outcome: Sendable {
        case unchanged
        case learned(openSSHKey: String)
    }

    private let knownKey: String?
    private let outcomeBox = NIOLockedValueBox<Outcome?>(nil)

    /// - Parameter knownKey: la clé OpenSSH déjà mémorisée pour cet hôte, ou `nil`.
    public init(knownKey: String?) {
        self.knownKey = knownKey
    }

    /// Résultat de la validation, disponible après la connexion.
    public var resolvedOutcome: Outcome? {
        outcomeBox.withLockedValue { $0 }
    }

    public func validateHostKey(hostKey: NIOSSHPublicKey, validationCompletePromise: EventLoopPromise<Void>) {
        let presented = String(openSSHPublicKey: hostKey)

        guard let knownKey else {
            outcomeBox.withLockedValue { $0 = .learned(openSSHKey: presented) }
            validationCompletePromise.succeed(())
            return
        }

        if knownKey == presented {
            outcomeBox.withLockedValue { $0 = .unchanged }
            validationCompletePromise.succeed(())
        } else {
            let fingerprint = HostKeyFingerprint.sha256(forOpenSSHKey: presented)
            validationCompletePromise.fail(SSHConnectionError.hostKeyChanged(fingerprint: fingerprint))
        }
    }
}
