import CommonCrypto
import Foundation

/// Déchiffrement AES (CTR et CBC, sans padding) via **CommonCrypto** — donc 100%
/// Apple, sans dépendance tierce. Utilisé pour la section privée d'une clé OpenSSH
/// chiffrée.
enum AESDecryptor {
    enum Mode {
        case ctr
        case cbc
    }

    static func decrypt(_ data: [UInt8], key: [UInt8], iv: [UInt8], mode: Mode) throws -> [UInt8] {
        switch mode {
        case .cbc:
            return try decryptCBC(data, key: key, iv: iv)
        case .ctr:
            return try decryptCTR(data, key: key, iv: iv)
        }
    }

    private static func decryptCBC(_ data: [UInt8], key: [UInt8], iv: [UInt8]) throws -> [UInt8] {
        var output = [UInt8](repeating: 0, count: data.count + kCCBlockSizeAES128)
        var moved = 0
        let status = CCCrypt(
            CCOperation(kCCDecrypt),
            CCAlgorithm(kCCAlgorithmAES),
            CCOptions(0), // pas de padding : la section est déjà alignée
            key, key.count,
            iv,
            data, data.count,
            &output, output.count,
            &moved
        )
        guard status == kCCSuccess else { throw OpenSSHKeyError.corrupt }
        return Array(output.prefix(moved))
    }

    private static func decryptCTR(_ data: [UInt8], key: [UInt8], iv: [UInt8]) throws -> [UInt8] {
        var cryptorOrNil: CCCryptorRef?
        let createStatus = CCCryptorCreateWithMode(
            CCOperation(kCCDecrypt),
            CCMode(kCCModeCTR),
            CCAlgorithm(kCCAlgorithmAES),
            CCPadding(ccNoPadding),
            iv,
            key, key.count,
            nil, 0,
            0,
            CCModeOptions(kCCModeOptionCTR_BE),
            &cryptorOrNil
        )
        guard createStatus == kCCSuccess, let cryptor = cryptorOrNil else {
            throw OpenSSHKeyError.corrupt
        }
        defer { CCCryptorRelease(cryptor) }

        var output = [UInt8](repeating: 0, count: data.count + kCCBlockSizeAES128)
        var movedUpdate = 0
        let updateStatus = CCCryptorUpdate(
            cryptor, data, data.count, &output, output.count, &movedUpdate
        )
        guard updateStatus == kCCSuccess else { throw OpenSSHKeyError.corrupt }

        var movedFinal = 0
        let finalStatus = output.withUnsafeMutableBytes { buffer -> CCCryptorStatus in
            let base = buffer.baseAddress!.advanced(by: movedUpdate)
            return CCCryptorFinal(cryptor, base, buffer.count - movedUpdate, &movedFinal)
        }
        guard finalStatus == kCCSuccess else { throw OpenSSHKeyError.corrupt }
        return Array(output.prefix(movedUpdate + movedFinal))
    }
}
