import Foundation
import Testing
@testable import SFTPKit

struct SFTPWireTests {
    private func appendUInt32(_ value: UInt32, to data: inout Data) {
        var bigEndian = value.bigEndian
        withUnsafeBytes(of: &bigEndian) { data.append(contentsOf: $0) }
    }

    private func appendUInt64(_ value: UInt64, to data: inout Data) {
        var bigEndian = value.bigEndian
        withUnsafeBytes(of: &bigEndian) { data.append(contentsOf: $0) }
    }

    @Test func writerFramesWithLengthPrefixAndRoundTrips() throws {
        var writer = SFTPPacketWriter(type: .open)
        writer.writeUInt32(7) // request id
        writer.writeString("/etc/hosts")
        writer.writeUInt32(SFTPOpenFlags.read.rawValue)
        writer.writeUInt32(0) // attributs vides
        let framed = writer.framed()

        let declaredLength = framed.prefix(4).reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        #expect(Int(declaredLength) == framed.count - 4)

        var reader = SFTPPacketReader(Data(framed.dropFirst(4)))
        #expect(try reader.readByte() == SFTPMessageType.open.rawValue)
        #expect(try reader.readUInt32() == 7)
        #expect(try reader.readString() == "/etc/hosts")
        #expect(try reader.readUInt32() == SFTPOpenFlags.read.rawValue)
    }

    @Test func readsDirectoryAttributes() throws {
        var body = Data()
        appendUInt32(0x0000_0004, to: &body) // flags: permissions
        appendUInt32(0x41ED, to: &body) // 0o040755 → S_IFDIR positionné

        var reader = SFTPPacketReader(body)
        let attributes = try reader.readAttributes()
        #expect(attributes.isDirectory)
        #expect(attributes.permissions == 0x41ED)
    }

    @Test func readsSizeAndModificationTime() throws {
        var body = Data()
        appendUInt32(0x0000_0001 | 0x0000_0008, to: &body) // size + acmodtime
        appendUInt64(123_456, to: &body) // size
        appendUInt32(1_000, to: &body) // atime
        appendUInt32(2_000, to: &body) // mtime

        var reader = SFTPPacketReader(body)
        let attributes = try reader.readAttributes()
        #expect(attributes.size == 123_456)
        #expect(attributes.modificationTime == 2_000)
        #expect(!attributes.isDirectory)
    }

    @Test func truncatedReadThrows() {
        var reader = SFTPPacketReader(Data([0x00, 0x01]))
        #expect(throws: SFTPError.self) {
            try reader.readUInt32()
        }
    }

    @Test func openFlagsCombine() {
        let flags: SFTPOpenFlags = [.write, .create, .truncate]
        #expect(flags.rawValue == (0x2 | 0x8 | 0x10))
    }
}
