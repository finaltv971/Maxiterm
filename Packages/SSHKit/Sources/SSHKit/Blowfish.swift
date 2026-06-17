import Foundation

// Variables mathématiques d'une lettre (demi-mots l/r, indices i/j/k, tableaux
// P/S, échelle M, terme u, base x) : conventions standard de Blowfish et de la
// formule de Machin.
// swiftlint:disable identifier_name

/// Implémentation de **Blowfish** et de sa variante salée **EksBlowfish**, telle
/// qu'utilisée par le KDF `bcrypt-pbkdf` d'OpenSSH.
///
/// Les constantes d'initialisation (tableau P de 18 mots + 4 boîtes-S de 256 mots)
/// sont **générées** à partir des décimales hexadécimales de π (formule de Machin,
/// arithmétique entière exacte), et non transcrites. Cela élimine 1042 constantes
/// magiques et rend l'état initial vérifiable (cf. ancrages connus dans les tests).
struct BlowfishState {
    var p: [UInt32]
    var s: [UInt32] // 4 boîtes de 256 mots, à plat : s[box * 256 + index]

    init() {
        p = BlowfishConstants.shared.p
        s = BlowfishConstants.shared.s
    }

    private func feistel(_ x: UInt32) -> UInt32 {
        let a = Int((x >> 24) & 0xFF)
        let b = Int((x >> 16) & 0xFF)
        let c = Int((x >> 8) & 0xFF)
        let d = Int(x & 0xFF)
        var y = s[a] &+ s[256 + b]
        y ^= s[512 + c]
        y = y &+ s[768 + d]
        return y
    }

    /// Chiffre un bloc de 64 bits (deux demi-mots).
    func encipher(_ left: inout UInt32, _ right: inout UInt32) {
        var l = left
        var r = right
        for i in 0 ..< 16 {
            l ^= p[i]
            r ^= feistel(l)
            swap(&l, &r)
        }
        swap(&l, &r)
        r ^= p[16]
        l ^= p[17]
        left = l
        right = r
    }

    /// Programmation de clé standard (sans sel).
    mutating func expand0(key: [UInt8]) {
        var j = 0
        for i in 0 ..< 18 { p[i] ^= BlowfishState.streamWord(key, &j) }
        var l: UInt32 = 0
        var r: UInt32 = 0
        var i = 0
        while i < 18 {
            encipher(&l, &r)
            p[i] = l
            p[i + 1] = r
            i += 2
        }
        for box in 0 ..< 4 {
            var k = 0
            while k < 256 {
                encipher(&l, &r)
                s[box * 256 + k] = l
                s[box * 256 + k + 1] = r
                k += 2
            }
        }
    }

    /// Programmation de clé salée (EksBlowfish) : mélange `data` (le sel) à chaque
    /// chiffrement de la table.
    mutating func expand(data: [UInt8], key: [UInt8]) {
        var j = 0
        for i in 0 ..< 18 { p[i] ^= BlowfishState.streamWord(key, &j) }
        var l: UInt32 = 0
        var r: UInt32 = 0
        var dj = 0
        var i = 0
        while i < 18 {
            l ^= BlowfishState.streamWord(data, &dj)
            r ^= BlowfishState.streamWord(data, &dj)
            encipher(&l, &r)
            p[i] = l
            p[i + 1] = r
            i += 2
        }
        for box in 0 ..< 4 {
            var k = 0
            while k < 256 {
                l ^= BlowfishState.streamWord(data, &dj)
                r ^= BlowfishState.streamWord(data, &dj)
                encipher(&l, &r)
                s[box * 256 + k] = l
                s[box * 256 + k + 1] = r
                k += 2
            }
        }
    }

    /// Lit 4 octets (cycliquement) depuis `data` pour former un mot big-endian.
    static func streamWord(_ data: [UInt8], _ j: inout Int) -> UInt32 {
        var temp: UInt32 = 0
        for _ in 0 ..< 4 {
            temp = (temp << 8) | UInt32(data[j])
            j = (j + 1) % data.count
        }
        return temp
    }

    /// Cœur de `bcrypt` : dérive 32 octets à partir de `sha2pass` et `sha2salt`
    /// (64 octets chacun), via 64 tours d'expansion salée puis 64 chiffrements de
    /// la chaîne magique.
    static func bcryptHash(sha2pass: [UInt8], sha2salt: [UInt8]) -> [UInt8] {
        var state = BlowfishState()
        state.expand(data: sha2salt, key: sha2pass)
        for _ in 0 ..< 64 {
            state.expand0(key: sha2salt)
            state.expand0(key: sha2pass)
        }

        let magic = Array("OxychromaticBlowfishSwatDynamite".utf8) // 32 octets
        var cdata = [UInt32](repeating: 0, count: 8)
        var j = 0
        for i in 0 ..< 8 { cdata[i] = streamWord(magic, &j) }

        for _ in 0 ..< 64 {
            var idx = 0
            while idx < 8 {
                var l = cdata[idx]
                var r = cdata[idx + 1]
                state.encipher(&l, &r)
                cdata[idx] = l
                cdata[idx + 1] = r
                idx += 2
            }
        }

        var out = [UInt8](repeating: 0, count: 32)
        for i in 0 ..< 8 {
            out[4 * i + 3] = UInt8((cdata[i] >> 24) & 0xFF)
            out[4 * i + 2] = UInt8((cdata[i] >> 16) & 0xFF)
            out[4 * i + 1] = UInt8((cdata[i] >> 8) & 0xFF)
            out[4 * i + 0] = UInt8(cdata[i] & 0xFF)
        }
        return out
    }
}

/// Table d'initialisation de Blowfish, calculée une seule fois à partir de π.
final class BlowfishConstants: @unchecked Sendable {
    static let shared = BlowfishConstants()

    let p: [UInt32] // 18 mots
    let s: [UInt32] // 1024 mots (4 × 256)

    private init() {
        let words = BlowfishConstants.piHexWords(count: 1042)
        p = Array(words[0 ..< 18])
        s = Array(words[18 ..< 1042])
    }

    /// Renvoie les `count` premiers mots de 32 bits formés par les décimales
    /// hexadécimales de la partie fractionnaire de π.
    ///
    /// π = 16·arctan(1/5) − 4·arctan(1/239) (formule de Machin), calculé en
    /// entiers à l'échelle `16^(M+G)` (avec G chiffres hexadécimaux de garde),
    /// puis on extrait les mots alignés. Tout est exact (aucun flottant).
    static func piHexWords(count: Int) -> [UInt32] {
        let M = count * 8 // chiffres hexadécimaux fractionnaires requis
        let guardDigits = 16
        let totalBits = 4 * (M + guardDigits)
        let scale = BigUInt.powerOfTwo(bits: totalBits)

        let (pos5, neg5) = arctanParts(scale: scale, x: 5)
        let (pos239, neg239) = arctanParts(scale: scale, x: 239)

        // π = 16·(pos5 − neg5) − 4·(pos239 − neg239)
        //   = (16·pos5 + 4·neg239) − (16·neg5 + 4·pos239)
        var positive = pos5
        positive.multiply(by: 16)
        var tmp = neg239
        tmp.multiply(by: 4)
        positive.add(tmp)

        var negative = neg5
        negative.multiply(by: 16)
        var tmp2 = pos239
        tmp2.multiply(by: 4)
        negative.add(tmp2)

        var piScaled = positive
        piScaled.subtract(negative)

        // Les mots sont alignés sur 32 bits : mot k = limbe (1043 − k).
        // (1043 = (4·(M + G − 8)) / 32 pour M = 8336, G = 16.)
        let topLimb = (4 * (M + guardDigits - 8)) / 32
        var result = [UInt32](repeating: 0, count: count)
        for k in 0 ..< count { result[k] = piScaled.limb(topLimb - k) }
        return result
    }

    /// Sommes positives (k pair) et négatives (k impair) de la série
    /// `arctan(1/x) = Σ (−1)^k / ((2k+1)·x^(2k+1))`, mises à l'échelle `scale`.
    private static func arctanParts(scale: BigUInt, x: UInt64) -> (pos: BigUInt, neg: BigUInt) {
        var u = scale
        u.divide(by: x) // u_0 = scale / x
        let xSquared = x * x
        var pos = BigUInt(0)
        var neg = BigUInt(0)
        var k: UInt64 = 0
        while !u.isZero {
            var term = u
            term.divide(by: 2 * k + 1)
            if k & 1 == 0 { pos.add(term) } else { neg.add(term) }
            u.divide(by: xSquared)
            k += 1
        }
        return (pos, neg)
    }
}

// swiftlint:enable identifier_name
