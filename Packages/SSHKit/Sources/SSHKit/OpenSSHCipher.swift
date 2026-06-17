import Foundation

/// Déchiffrement de la section privée d'une clé OpenSSH protégée par phrase de
/// passe : KDF **bcrypt-pbkdf** (cf. ``BcryptPBKDF``) puis **AES** CTR/CBC (cf.
/// ``AESDecryptor``). 100% Apple, sans dépendance tierce.
enum OpenSSHCipher {
    private struct CipherParams {
        let keyLength: Int
        let ivLength: Int
        let mode: AESDecryptor.Mode
    }

    static func decrypt(
        _ data: [UInt8],
        cipher: String,
        kdf: String,
        kdfOptions: [UInt8],
        passphrase: String
    ) throws -> [UInt8] {
        guard kdf == "bcrypt" else { throw OpenSSHKeyError.unsupportedCipher(cipher) }
        let params = try cipherParams(for: cipher)

        // kdfOptions = string(salt) || uint32(rounds)
        var reader = SSHByteReader(Data(kdfOptions))
        let salt = try reader.readSSHString()
        let rounds = Int(try reader.readUInt32())
        guard rounds >= 1, !salt.isEmpty else { throw OpenSSHKeyError.corrupt }

        let derived = BcryptPBKDF.derive(
            passphrase: Array(passphrase.utf8),
            salt: salt,
            rounds: rounds,
            keyLength: params.keyLength + params.ivLength
        )
        let key = Array(derived.prefix(params.keyLength))
        let iv = Array(derived.suffix(params.ivLength))

        return try AESDecryptor.decrypt(data, key: key, iv: iv, mode: params.mode)
    }

    private static func cipherParams(for cipher: String) throws -> CipherParams {
        switch cipher {
        case "aes256-ctr": return CipherParams(keyLength: 32, ivLength: 16, mode: .ctr)
        case "aes192-ctr": return CipherParams(keyLength: 24, ivLength: 16, mode: .ctr)
        case "aes128-ctr": return CipherParams(keyLength: 16, ivLength: 16, mode: .ctr)
        case "aes256-cbc": return CipherParams(keyLength: 32, ivLength: 16, mode: .cbc)
        case "aes192-cbc": return CipherParams(keyLength: 24, ivLength: 16, mode: .cbc)
        case "aes128-cbc": return CipherParams(keyLength: 16, ivLength: 16, mode: .cbc)
        default: throw OpenSSHKeyError.unsupportedCipher(cipher)
        }
    }
}
