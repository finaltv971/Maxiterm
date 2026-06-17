import Foundation

/// Types de message SFTP (protocole v3).
enum SFTPMessageType: UInt8 {
    case initialize = 1 // SSH_FXP_INIT
    case version = 2
    case open = 3
    case close = 4
    case read = 5
    case write = 6
    case fstat = 8
    case setstat = 9
    case opendir = 11
    case readdir = 12
    case remove = 13
    case mkdir = 14
    case rmdir = 15
    case realpath = 16
    case stat = 17
    case rename = 18
    case status = 101
    case handle = 102
    case data = 103
    case name = 104
    case attrs = 105
}

/// Codes de statut SFTP usuels.
enum SFTPStatus {
    static let ok: UInt32 = 0
    static let eof: UInt32 = 1
}

/// Drapeaux d'ouverture de fichier (SSH_FXF_*).
struct SFTPOpenFlags: OptionSet {
    let rawValue: UInt32
    static let read = SFTPOpenFlags(rawValue: 0x0000_0001)
    static let write = SFTPOpenFlags(rawValue: 0x0000_0002)
    static let append = SFTPOpenFlags(rawValue: 0x0000_0004)
    static let create = SFTPOpenFlags(rawValue: 0x0000_0008)
    static let truncate = SFTPOpenFlags(rawValue: 0x0000_0010)
}

/// Attributs de fichier SFTP (sous-ensemble exploité).
struct SFTPAttributes {
    var size: UInt64?
    var permissions: UInt32?
    var modificationTime: UInt32?

    /// `true` si le bit S_IFDIR est positionné dans les permissions.
    var isDirectory: Bool {
        guard let permissions else { return false }
        return (permissions & 0xF000) == 0x4000
    }
}

/// Entrée brute d'une réponse SSH_FXP_NAME.
struct SFTPNameEntry {
    let filename: String
    let longname: String
    let attributes: SFTPAttributes
}

/// Réponse SFTP décodée, corrélée à une requête.
enum SFTPResponse {
    case status(code: UInt32, message: String)
    case handle(Data)
    case data(Data)
    case name([SFTPNameEntry])
    case attributes(SFTPAttributes)
}

/// Construit un paquet SFTP (type + charge utile) puis l'encadre par sa longueur.
struct SFTPPacketWriter {
    private var body = Data()

    init(type: SFTPMessageType) {
        body.append(type.rawValue)
    }

    mutating func writeUInt32(_ value: UInt32) {
        var bigEndian = value.bigEndian
        withUnsafeBytes(of: &bigEndian) { body.append(contentsOf: $0) }
    }

    mutating func writeUInt64(_ value: UInt64) {
        var bigEndian = value.bigEndian
        withUnsafeBytes(of: &bigEndian) { body.append(contentsOf: $0) }
    }

    mutating func writeData(_ data: Data) {
        writeUInt32(UInt32(data.count))
        body.append(data)
    }

    mutating func writeString(_ string: String) {
        writeData(Data(string.utf8))
    }

    /// Retourne le paquet préfixé de sa longueur (uint32 big-endian).
    func framed() -> Data {
        var output = Data()
        var length = UInt32(body.count).bigEndian
        withUnsafeBytes(of: &length) { output.append(contentsOf: $0) }
        output.append(body)
        return output
    }
}

/// Lecture séquentielle d'un corps de paquet SFTP (type déjà retiré possible).
struct SFTPPacketReader {
    private let bytes: [UInt8]
    private var offset = 0

    init(_ data: Data) {
        self.bytes = Array(data)
    }

    mutating func readByte() throws -> UInt8 {
        guard offset < bytes.count else { throw SFTPError.malformedResponse }
        defer { offset += 1 }
        return bytes[offset]
    }

    mutating func readUInt32() throws -> UInt32 {
        guard offset + 4 <= bytes.count else { throw SFTPError.malformedResponse }
        defer { offset += 4 }
        return bytes[offset ..< offset + 4].reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
    }

    mutating func readUInt64() throws -> UInt64 {
        guard offset + 8 <= bytes.count else { throw SFTPError.malformedResponse }
        defer { offset += 8 }
        return bytes[offset ..< offset + 8].reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
    }

    mutating func readData() throws -> Data {
        let length = Int(try readUInt32())
        guard offset + length <= bytes.count else { throw SFTPError.malformedResponse }
        defer { offset += length }
        return Data(bytes[offset ..< offset + length])
    }

    mutating func readString() throws -> String {
        String(decoding: try readData(), as: UTF8.self)
    }

    mutating func readAttributes() throws -> SFTPAttributes {
        let flags = try readUInt32()
        var attributes = SFTPAttributes()
        if flags & 0x0000_0001 != 0 { attributes.size = try readUInt64() }
        if flags & 0x0000_0002 != 0 { _ = try readUInt32(); _ = try readUInt32() } // uid, gid
        if flags & 0x0000_0004 != 0 { attributes.permissions = try readUInt32() }
        if flags & 0x0000_0008 != 0 {
            _ = try readUInt32() // atime
            attributes.modificationTime = try readUInt32()
        }
        if flags & 0x8000_0000 != 0 {
            let count = try readUInt32()
            for _ in 0 ..< count {
                _ = try readString()
                _ = try readString()
            }
        }
        return attributes
    }
}
