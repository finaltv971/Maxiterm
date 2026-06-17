import Foundation

/// Transferts de fichiers **en streaming** (sans charger le contenu en mémoire),
/// avec progression, plus `stat` et `chmod`.
public extension SFTPClient {
    /// Télécharge un fichier distant vers un fichier local, bloc par bloc.
    func downloadFile(
        at path: String,
        to localURL: URL,
        progress: SFTPTransferProgress? = nil
    ) async throws {
        let total = try? await stat(path).size
        let handle = try await open(file: path, flags: [.read])
        FileManager.default.createFile(atPath: localURL.path, contents: nil)
        guard let fileHandle = try? FileHandle(forWritingTo: localURL) else {
            await close(handle: handle)
            throw SFTPError.connectionFailed("écriture locale impossible (\(localURL.lastPathComponent))")
        }

        var offset: UInt64 = 0
        do {
            readLoop: while true {
                var writer = SFTPPacketWriter(type: .read)
                let id = allocateID(into: &writer)
                writer.writeData(handle)
                writer.writeUInt64(offset)
                writer.writeUInt32(UInt32(SFTPClient.chunkSize))
                let response = try await roundtrip(writer.framed(), id: id)
                switch response {
                case let .data(chunk):
                    try fileHandle.write(contentsOf: chunk)
                    offset += UInt64(chunk.count)
                    progress?(offset, total)
                case let .status(code, message):
                    if code == SFTPStatus.eof { break readLoop }
                    throw SFTPError.status(code: code, message: message)
                default:
                    throw SFTPError.malformedResponse
                }
            }
        } catch {
            try? fileHandle.close()
            await close(handle: handle)
            throw error
        }
        try? fileHandle.close()
        await close(handle: handle)
    }

    /// Envoie un fichier local vers un chemin distant, bloc par bloc.
    func uploadFile(
        from localURL: URL,
        to path: String,
        progress: SFTPTransferProgress? = nil
    ) async throws {
        let total = SFTPClient.localFileSize(localURL)
        guard let fileHandle = try? FileHandle(forReadingFrom: localURL) else {
            throw SFTPError.connectionFailed("lecture locale impossible (\(localURL.lastPathComponent))")
        }
        let handle = try await open(file: path, flags: [.write, .create, .truncate])

        var offset: UInt64 = 0
        do {
            while true {
                let chunk = try fileHandle.read(upToCount: SFTPClient.chunkSize) ?? Data()
                if chunk.isEmpty { break }
                var writer = SFTPPacketWriter(type: .write)
                let id = allocateID(into: &writer)
                writer.writeData(handle)
                writer.writeUInt64(offset)
                writer.writeData(chunk)
                try await expectOK(writer.framed(), id: id)
                offset += UInt64(chunk.count)
                progress?(offset, total)
            }
        } catch {
            try? fileHandle.close()
            await close(handle: handle)
            throw error
        }
        try? fileHandle.close()
        await close(handle: handle)
    }

    /// Modifie les permissions POSIX d'un chemin distant (`chmod`).
    /// `permissions` = bits rwx + setuid/setgid/sticky (12 bits bas, ex. 0o644).
    func setPermissions(_ permissions: UInt32, at path: String) async throws {
        var writer = SFTPPacketWriter(type: .setstat)
        let id = allocateID(into: &writer)
        writer.writeString(path)
        writer.writeUInt32(0x0000_0004) // SSH_FILEXFER_ATTR_PERMISSIONS
        writer.writeUInt32(permissions & 0o7777)
        try await expectOK(writer.framed(), id: id)
    }

    /// Lit les attributs d'un chemin distant (taille, permissions, mtime).
    internal func stat(_ path: String) async throws -> SFTPAttributes {
        var writer = SFTPPacketWriter(type: .stat)
        let id = allocateID(into: &writer)
        writer.writeString(path)
        let response = try await roundtrip(writer.framed(), id: id)
        guard case let .attributes(attributes) = response else { throw error(from: response) }
        return attributes
    }

    /// Taille d'un fichier local, ou `nil` si inaccessible.
    internal static func localFileSize(_ url: URL) -> UInt64? {
        guard
            let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
            let size = attributes[.size] as? NSNumber
        else { return nil }
        return size.uint64Value
    }
}
