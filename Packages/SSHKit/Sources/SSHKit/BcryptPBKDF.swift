import Crypto
import Foundation

// Indice de boucle `j` d'une lettre, idiomatique pour le mélange octet à octet.
// swiftlint:disable identifier_name

/// KDF **bcrypt-pbkdf** d'OpenSSH : dérive une clé de longueur arbitraire à partir
/// d'une phrase de passe et d'un sel, en `rounds` itérations. Combine SHA-512
/// (swift-crypto) et le cœur `bcrypt` (EksBlowfish, cf. ``BlowfishState``).
///
/// Algorithme identique à `bcrypt_pbkdf` d'OpenBSD.
enum BcryptPBKDF {
    static func derive(passphrase: [UInt8], salt: [UInt8], rounds: Int, keyLength: Int) -> [UInt8] {
        precondition(rounds >= 1 && keyLength > 0 && !salt.isEmpty)

        let blockSize = 32
        let sha2pass = Array(SHA512.hash(data: passphrase))

        let stride = (keyLength + blockSize - 1) / blockSize
        var amount = (keyLength + stride - 1) / stride

        var key = [UInt8](repeating: 0, count: keyLength)
        var remaining = keyLength
        var count: UInt32 = 1

        while remaining > 0 {
            var countSalt = salt
            countSalt.append(UInt8((count >> 24) & 0xFF))
            countSalt.append(UInt8((count >> 16) & 0xFF))
            countSalt.append(UInt8((count >> 8) & 0xFF))
            countSalt.append(UInt8(count & 0xFF))

            var sha2salt = Array(SHA512.hash(data: countSalt))
            var tmpout = BlowfishState.bcryptHash(sha2pass: sha2pass, sha2salt: sha2salt)
            var out = tmpout

            var round = 1
            while round < rounds {
                sha2salt = Array(SHA512.hash(data: tmpout))
                tmpout = BlowfishState.bcryptHash(sha2pass: sha2pass, sha2salt: sha2salt)
                for j in 0 ..< blockSize { out[j] ^= tmpout[j] }
                round += 1
            }

            amount = min(amount, remaining)
            var i = 0
            while i < amount {
                let dest = i * stride + Int(count - 1)
                if dest >= keyLength { break }
                key[dest] = out[i]
                i += 1
            }
            remaining -= i
            count += 1
        }
        return key
    }
}

// swiftlint:enable identifier_name
