import Crypto
import Foundation
import NIOSSH

/// Erreurs de parsing d'une clé privée OpenSSH.
public enum OpenSSHKeyError: LocalizedError, Equatable {
    case invalidArmor
    case invalidBase64
    case unsupportedMagic
    case encryptedKeyNeedsPassphrase
    case wrongPassphrase
    case corrupt
    case unsupportedKeyType(String)
    case unsupportedCipher(String)

    public var errorDescription: String? {
        switch self {
        case .invalidArmor: return "Format de clé OpenSSH invalide."
        case .invalidBase64: return "Contenu de clé illisible (base64)."
        case .unsupportedMagic: return "Ce n'est pas une clé OpenSSH."
        case .encryptedKeyNeedsPassphrase: return "Cette clé est chiffrée : une phrase de passe est requise."
        case .wrongPassphrase: return "Phrase de passe incorrecte."
        case .corrupt: return "Clé OpenSSH corrompue."
        case let .unsupportedKeyType(type): return "Type de clé non pris en charge : \(type)."
        case let .unsupportedCipher(cipher): return "Chiffrement de clé non pris en charge : \(cipher)."
        }
    }
}

/// Parser de clés privées **OpenSSH** (`-----BEGIN OPENSSH PRIVATE KEY-----`).
///
/// Types pris en charge : **Ed25519** et **ECDSA** (nistp256/384/521) — ce que
/// `swift-nio-ssh` sait utiliser pour l'authentification. Les clés **chiffrées**
/// (bcrypt-pbkdf + AES-CTR) sont déchiffrées si une phrase de passe est fournie.
///
/// > RSA n'est volontairement pas géré : `swift-nio-ssh` ne propose pas de clé
/// > privée RSA côté client.
public enum OpenSSHPrivateKey {
    private static let magic = Array("openssh-key-v1\u{0}".utf8)

    public static func parse(pem: String, passphrase: String? = nil) throws -> NIOSSHPrivateKey {
        let blob = try decodeArmor(pem)
        var reader = SSHByteReader(blob)

        guard let header = reader.read(count: magic.count), Array(header) == magic else {
            throw OpenSSHKeyError.unsupportedMagic
        }

        let cipherName = try reader.readSSHStringAsText()
        let kdfName = try reader.readSSHStringAsText()
        let kdfOptions = try reader.readSSHString()
        let keyCount = try reader.readUInt32()
        guard keyCount == 1 else { throw OpenSSHKeyError.corrupt }
        _ = try reader.readSSHString() // clé publique
        let privateSection = try reader.readSSHString()

        let privateBytes: [UInt8]
        if cipherName == "none", kdfName == "none" {
            privateBytes = privateSection
        } else {
            guard let passphrase, !passphrase.isEmpty else {
                throw OpenSSHKeyError.encryptedKeyNeedsPassphrase
            }
            privateBytes = try OpenSSHCipher.decrypt(
                privateSection,
                cipher: cipherName,
                kdf: kdfName,
                kdfOptions: kdfOptions,
                passphrase: passphrase
            )
        }

        var priv = SSHByteReader(Data(privateBytes))
        let check1 = try priv.readUInt32()
        let check2 = try priv.readUInt32()
        // Un mauvais mot de passe casse cette égalité (la section déchiffrée est fausse).
        guard check1 == check2 else {
            throw cipherName == "none" ? OpenSSHKeyError.corrupt : OpenSSHKeyError.wrongPassphrase
        }

        let keyType = try priv.readSSHStringAsText()
        return try makePrivateKey(type: keyType, reader: &priv)
    }

    // MARK: - Construction par type

    private static func makePrivateKey(type: String, reader: inout SSHByteReader) throws -> NIOSSHPrivateKey {
        switch type {
        case "ssh-ed25519":
            _ = try reader.readSSHString() // clé publique (32)
            let priv = try reader.readSSHString() // 64 = graine(32) + pub(32)
            guard priv.count == 64 else { throw OpenSSHKeyError.corrupt }
            let seed = Data(priv.prefix(32))
            guard let key = try? Curve25519.Signing.PrivateKey(rawRepresentation: seed) else {
                throw OpenSSHKeyError.corrupt
            }
            return NIOSSHPrivateKey(ed25519Key: key)

        case "ecdsa-sha2-nistp256":
            let scalar = try readECDSAScalar(reader: &reader, size: 32)
            guard let key = try? P256.Signing.PrivateKey(rawRepresentation: scalar) else {
                throw OpenSSHKeyError.corrupt
            }
            return NIOSSHPrivateKey(p256Key: key)

        case "ecdsa-sha2-nistp384":
            let scalar = try readECDSAScalar(reader: &reader, size: 48)
            guard let key = try? P384.Signing.PrivateKey(rawRepresentation: scalar) else {
                throw OpenSSHKeyError.corrupt
            }
            return NIOSSHPrivateKey(p384Key: key)

        case "ecdsa-sha2-nistp521":
            let scalar = try readECDSAScalar(reader: &reader, size: 66)
            guard let key = try? P521.Signing.PrivateKey(rawRepresentation: scalar) else {
                throw OpenSSHKeyError.corrupt
            }
            return NIOSSHPrivateKey(p521Key: key)

        default:
            throw OpenSSHKeyError.unsupportedKeyType(type)
        }
    }

    private static func readECDSAScalar(reader: inout SSHByteReader, size: Int) throws -> Data {
        _ = try reader.readSSHString() // nom de courbe
        _ = try reader.readSSHString() // point public Q
        let scalarBytes = try reader.readSSHString() // exposant privé (mpint)
        return normalizeScalar(scalarBytes, size: size)
    }

    /// Normalise un scalaire mpint vers une taille fixe (retire le zéro de signe,
    /// complète à gauche par des zéros).
    private static func normalizeScalar(_ bytes: [UInt8], size: Int) -> Data {
        var value = bytes
        while value.first == 0, value.count > size { value.removeFirst() }
        if value.count < size { value = Array(repeating: 0, count: size - value.count) + value }
        if value.count > size { value = Array(value.suffix(size)) }
        return Data(value)
    }

    // MARK: - Armure

    static func decodeArmor(_ pem: String) throws -> Data {
        let lines = pem.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
        let body = lines.filter { !$0.hasPrefix("-----") && !$0.isEmpty }
        guard pem.contains("OPENSSH PRIVATE KEY"), !body.isEmpty else {
            throw OpenSSHKeyError.invalidArmor
        }
        guard let data = Data(base64Encoded: body.joined()) else {
            throw OpenSSHKeyError.invalidBase64
        }
        return data
    }
}

/// Lecteur d'octets big-endian avec primitives SSH (uint32, string longueur-préfixée).
struct SSHByteReader {
    private let bytes: [UInt8]
    private var offset = 0

    init(_ data: Data) { self.bytes = Array(data) }

    mutating func read(count: Int) -> ArraySlice<UInt8>? {
        guard count >= 0, offset + count <= bytes.count else { return nil }
        defer { offset += count }
        return bytes[offset ..< offset + count]
    }

    mutating func readUInt32() throws -> UInt32 {
        guard let slice = read(count: 4) else { throw OpenSSHKeyError.corrupt }
        return slice.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
    }

    mutating func readSSHString() throws -> [UInt8] {
        let length = try readUInt32()
        guard let slice = read(count: Int(length)) else { throw OpenSSHKeyError.corrupt }
        return Array(slice)
    }

    mutating func readSSHStringAsText() throws -> String {
        String(bytes: try readSSHString(), encoding: .utf8) ?? ""
    }
}
