import Foundation

// Indices de boucle d'une lettre, idiomatiques pour l'arithmétique multi-limbes.
// swiftlint:disable identifier_name

/// Entier non signé de précision arbitraire, **minimal** et **interne**.
///
/// Sert uniquement à générer les constantes d'initialisation de Blowfish à partir
/// des décimales hexadécimales de π (formule de Machin), en arithmétique entière
/// exacte — ce qui évite de transcrire 1042 constantes « magiques » et rend la
/// table entièrement auditable. Les limbes sont stockés en little-endian sur 32 bits.
struct BigUInt {
    private(set) var limbs: [UInt32]

    init(_ value: UInt32 = 0) { limbs = [value] }

    /// `2^bits`.
    static func powerOfTwo(bits: Int) -> BigUInt {
        var result = BigUInt(0)
        let limbIndex = bits / 32
        result.limbs = [UInt32](repeating: 0, count: limbIndex + 1)
        result.limbs[limbIndex] = UInt32(1) << UInt32(bits % 32)
        return result
    }

    var isZero: Bool { limbs.allSatisfy { $0 == 0 } }

    /// Renvoie le limbe `index` (0 si hors borne).
    func limb(_ index: Int) -> UInt32 {
        index >= 0 && index < limbs.count ? limbs[index] : 0
    }

    /// Division entière en place par un petit diviseur ; renvoie le reste.
    @discardableResult
    mutating func divide(by divisor: UInt64) -> UInt64 {
        var remainder: UInt64 = 0
        var i = limbs.count - 1
        while i >= 0 {
            let current = (remainder << 32) | UInt64(limbs[i])
            limbs[i] = UInt32(current / divisor)
            remainder = current % divisor
            i -= 1
        }
        return remainder
    }

    /// Multiplication en place par un petit facteur.
    mutating func multiply(by factor: UInt64) {
        var carry: UInt64 = 0
        for i in 0 ..< limbs.count {
            let current = UInt64(limbs[i]) * factor + carry
            limbs[i] = UInt32(current & 0xFFFF_FFFF)
            carry = current >> 32
        }
        while carry > 0 {
            limbs.append(UInt32(carry & 0xFFFF_FFFF))
            carry >>= 32
        }
    }

    /// Addition en place.
    mutating func add(_ other: BigUInt) {
        let count = max(limbs.count, other.limbs.count)
        if limbs.count < count { limbs += [UInt32](repeating: 0, count: count - limbs.count) }
        var carry: UInt64 = 0
        for i in 0 ..< count {
            let rhs = i < other.limbs.count ? UInt64(other.limbs[i]) : 0
            let current = UInt64(limbs[i]) + rhs + carry
            limbs[i] = UInt32(current & 0xFFFF_FFFF)
            carry = current >> 32
        }
        if carry > 0 { limbs.append(UInt32(carry & 0xFFFF_FFFF)) }
    }

    /// Soustraction en place (suppose `self >= other`).
    mutating func subtract(_ other: BigUInt) {
        var borrow: Int64 = 0
        for i in 0 ..< limbs.count {
            let rhs = i < other.limbs.count ? Int64(other.limbs[i]) : 0
            var current = Int64(limbs[i]) - rhs - borrow
            if current < 0 {
                current += Int64(1) << 32
                borrow = 1
            } else {
                borrow = 0
            }
            limbs[i] = UInt32(current)
        }
    }
}

// swiftlint:enable identifier_name
