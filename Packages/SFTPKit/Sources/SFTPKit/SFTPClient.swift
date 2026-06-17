import Core
import Foundation
import SSHKit

/// Client SFTP v3 « maison », bâti sur un canal de sous-système SSHKit.
///
/// `actor` : la table des requêtes en attente et le tampon de réassemblage sont
/// sérialisés, évitant toute course entre l'envoi de requêtes et la boucle de
/// lecture du réseau.
public actor SFTPClient {
    private let connection: SSHRawConnection
    private let channel: SSHByteChannel
    private let learnedKey: String?

    private var nextRequestID: UInt32 = 0
    private var pending: [UInt32: CheckedContinuation<SFTPResponse, Error>] = [:]
    private var versionContinuation: CheckedContinuation<Void, Error>?
    private var inboundBuffer = Data()
    private var readerTask: Task<Void, Never>?

    static let chunkSize = 32_768

    private init(connection: SSHRawConnection, channel: SSHByteChannel, learnedKey: String?) {
        self.connection = connection
        self.channel = channel
        self.learnedKey = learnedKey
    }

    // MARK: - Cycle de vie

    /// Ouvre une connexion SSH dédiée (avec TOFU), démarre le sous-système SFTP
    /// et négocie la version du protocole.
    public static func connect(
        to host: SSHHost,
        credential: SSHCredential,
        knownHostKey: String? = nil,
        jump: SSHJumpConfig? = nil
    ) async throws -> SFTPClient {
        let connection: SSHRawConnection
        if let jump {
            connection = try await SSHRawConnection.connectThroughJump(
                jump: jump,
                target: host,
                targetCredential: credential,
                targetKnownHostKey: knownHostKey
            )
        } else {
            connection = try await SSHRawConnection.connect(
                to: host,
                credential: credential,
                knownHostKey: knownHostKey
            )
        }
        let learned = await connection.learnedHostKey()
        let channel = try await connection.openSubsystem("sftp")
        let client = SFTPClient(connection: connection, channel: channel, learnedKey: learned)
        await client.startReader()
        try await client.negotiateVersion()
        return client
    }

    /// Clé hôte apprise lors d'une première connexion (TOFU), ou `nil`.
    public func learnedHostKey() -> String? { learnedKey }

    public func disconnect() async {
        readerTask?.cancel()
        readerTask = nil
        await channel.close()
        await connection.close()
        failAllPending(with: SFTPError.connectionFailed("Session fermée."))
    }

    // MARK: - Opérations

    /// Résout un chemin (souvent ".") en chemin absolu côté serveur.
    public func realPath(_ path: String) async throws -> String {
        var writer = SFTPPacketWriter(type: .realpath)
        let id = allocateID(into: &writer)
        writer.writeString(path)
        let response = try await roundtrip(writer.framed(), id: id)
        guard case let .name(entries) = response, let first = entries.first else {
            throw error(from: response)
        }
        return first.filename
    }

    /// Liste le contenu d'un répertoire (hors `.` et `..`).
    public func listDirectory(_ path: String) async throws -> [SFTPFile] {
        let handle = try await open(directory: path)
        var files: [SFTPFile] = []
        do {
            readLoop: while true {
                var writer = SFTPPacketWriter(type: .readdir)
                let id = allocateID(into: &writer)
                writer.writeData(handle)
                let response = try await roundtrip(writer.framed(), id: id)
                switch response {
                case let .name(entries):
                    for entry in entries where entry.filename != "." && entry.filename != ".." {
                        files.append(makeFile(parent: path, entry: entry))
                    }
                case let .status(code, message):
                    if code == SFTPStatus.eof { break readLoop }
                    throw SFTPError.status(code: code, message: message)
                default:
                    throw SFTPError.malformedResponse
                }
            }
        } catch {
            await close(handle: handle)
            throw error
        }
        await close(handle: handle)
        return files.sorted { lhs, rhs in
            (lhs.isDirectory ? 0 : 1, lhs.name.lowercased()) < (rhs.isDirectory ? 0 : 1, rhs.name.lowercased())
        }
    }

    public func makeDirectory(_ path: String) async throws {
        var writer = SFTPPacketWriter(type: .mkdir)
        let id = allocateID(into: &writer)
        writer.writeString(path)
        writer.writeUInt32(0) // attributs vides
        try await expectOK(writer.framed(), id: id)
    }

    public func removeFile(_ path: String) async throws {
        var writer = SFTPPacketWriter(type: .remove)
        let id = allocateID(into: &writer)
        writer.writeString(path)
        try await expectOK(writer.framed(), id: id)
    }

    public func removeDirectory(_ path: String) async throws {
        var writer = SFTPPacketWriter(type: .rmdir)
        let id = allocateID(into: &writer)
        writer.writeString(path)
        try await expectOK(writer.framed(), id: id)
    }

    public func rename(_ source: String, to destination: String) async throws {
        var writer = SFTPPacketWriter(type: .rename)
        let id = allocateID(into: &writer)
        writer.writeString(source)
        writer.writeString(destination)
        try await expectOK(writer.framed(), id: id)
    }

    // MARK: - Primitives privées

    func open(file path: String, flags: SFTPOpenFlags) async throws -> Data {
        var writer = SFTPPacketWriter(type: .open)
        let id = allocateID(into: &writer)
        writer.writeString(path)
        writer.writeUInt32(flags.rawValue)
        writer.writeUInt32(0) // attributs vides
        let response = try await roundtrip(writer.framed(), id: id)
        guard case let .handle(handle) = response else { throw error(from: response) }
        return handle
    }

    private func open(directory path: String) async throws -> Data {
        var writer = SFTPPacketWriter(type: .opendir)
        let id = allocateID(into: &writer)
        writer.writeString(path)
        let response = try await roundtrip(writer.framed(), id: id)
        guard case let .handle(handle) = response else { throw error(from: response) }
        return handle
    }

    func close(handle: Data) async {
        var writer = SFTPPacketWriter(type: .close)
        let id = allocateID(into: &writer)
        writer.writeData(handle)
        _ = try? await roundtrip(writer.framed(), id: id)
    }

    func expectOK(_ packet: Data, id: UInt32) async throws {
        let response = try await roundtrip(packet, id: id)
        guard case let .status(code, message) = response else { throw SFTPError.malformedResponse }
        guard code == SFTPStatus.ok else { throw SFTPError.status(code: code, message: message) }
    }

    func allocateID(into writer: inout SFTPPacketWriter) -> UInt32 {
        nextRequestID &+= 1
        let id = nextRequestID
        writer.writeUInt32(id)
        return id
    }

    /// Enregistre la requête **avant** l'envoi (l'actor empêche toute course
    /// avec la boucle de lecture), puis attend la réponse corrélée.
    func roundtrip(_ packet: Data, id: UInt32) async throws -> SFTPResponse {
        try await withCheckedThrowingContinuation { continuation in
            pending[id] = continuation
            let channel = self.channel
            Task {
                do {
                    try await channel.send(packet)
                } catch {
                    await self.failPending(id, with: error)
                }
            }
        }
    }

    private func negotiateVersion() async throws {
        var writer = SFTPPacketWriter(type: .initialize)
        writer.writeUInt32(3) // version
        let packet = writer.framed()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            versionContinuation = continuation
            let channel = self.channel
            Task {
                do {
                    try await channel.send(packet)
                } catch {
                    await self.failVersion(with: error)
                }
            }
        }
    }

    private func startReader() {
        readerTask = Task { [weak self] in
            guard let self else { return }
            for await chunk in await self.channel.inbound {
                await self.ingest(chunk)
            }
            await self.failAllPending(with: SFTPError.connectionFailed("Flux interrompu."))
        }
    }

    private func ingest(_ chunk: Data) {
        inboundBuffer.append(chunk)
        while inboundBuffer.count >= 4 {
            let length = Int(inboundBuffer.prefix(4).reduce(UInt32(0)) { ($0 << 8) | UInt32($1) })
            let total = 4 + length
            guard inboundBuffer.count >= total else { break }
            let body = Data(inboundBuffer.prefix(total).dropFirst(4))
            inboundBuffer.removeFirst(total)
            handlePacket(body)
        }
    }

    private func handlePacket(_ body: Data) {
        var reader = SFTPPacketReader(body)
        guard let rawType = try? reader.readByte(), let type = SFTPMessageType(rawValue: rawType) else { return }

        if type == .version {
            versionContinuation?.resume()
            versionContinuation = nil
            return
        }

        guard let id = try? reader.readUInt32() else { return }
        guard let continuation = pending.removeValue(forKey: id) else { return }

        do {
            continuation.resume(returning: try parseResponse(type: type, reader: &reader))
        } catch {
            continuation.resume(throwing: error)
        }
    }

    private func parseResponse(type: SFTPMessageType, reader: inout SFTPPacketReader) throws -> SFTPResponse {
        switch type {
        case .status:
            let code = try reader.readUInt32()
            let message = (try? reader.readString()) ?? ""
            return .status(code: code, message: message)
        case .handle:
            return .handle(try reader.readData())
        case .data:
            return .data(try reader.readData())
        case .name:
            let count = try reader.readUInt32()
            var entries: [SFTPNameEntry] = []
            for _ in 0 ..< count {
                let filename = try reader.readString()
                let longname = try reader.readString()
                let attributes = try reader.readAttributes()
                entries.append(SFTPNameEntry(filename: filename, longname: longname, attributes: attributes))
            }
            return .name(entries)
        case .attrs:
            return .attributes(try reader.readAttributes())
        default:
            throw SFTPError.malformedResponse
        }
    }

    private func makeFile(parent: String, entry: SFTPNameEntry) -> SFTPFile {
        let base = parent.hasSuffix("/") ? parent : parent + "/"
        let isDirectory = entry.attributes.isDirectory || entry.longname.first == "d"
        let modificationDate = entry.attributes.modificationTime.map { Date(timeIntervalSince1970: TimeInterval($0)) }
        return SFTPFile(
            name: entry.filename,
            path: base + entry.filename,
            isDirectory: isDirectory,
            size: entry.attributes.size,
            modificationDate: modificationDate
        )
    }

    func error(from response: SFTPResponse) -> Error {
        if case let .status(code, message) = response {
            return SFTPError.status(code: code, message: message)
        }
        return SFTPError.malformedResponse
    }

    private func failPending(_ id: UInt32, with error: Error) {
        pending.removeValue(forKey: id)?.resume(throwing: error)
    }

    private func failVersion(with error: Error) {
        versionContinuation?.resume(throwing: error)
        versionContinuation = nil
    }

    private func failAllPending(with error: Error) {
        for continuation in pending.values {
            continuation.resume(throwing: error)
        }
        pending.removeAll()
        versionContinuation?.resume(throwing: error)
        versionContinuation = nil
    }
}
