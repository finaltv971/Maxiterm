import Core
import Foundation
import Persistence
import SFTPKit
import SSHKit

/// Pilote l'écran ``SFTPBrowserView`` : connexion SFTP, navigation et transferts.
@MainActor
final class SFTPBrowserModel: ObservableObject {
    enum Status: Equatable {
        case connecting
        case ready
        case failed(String)
    }

    /// Sens d'un transfert.
    enum TransferKind: Equatable { case download, upload }

    /// État d'un transfert en cours (pour la barre de progression).
    struct TransferState: Equatable {
        let kind: TransferKind
        let name: String
        var transferred: UInt64
        var total: UInt64?

        var fraction: Double? {
            guard let total, total > 0 else { return nil }
            return min(1, Double(transferred) / Double(total))
        }
    }

    @Published private(set) var status: Status = .connecting
    @Published private(set) var path = "/"
    @Published private(set) var files: [SFTPFile] = []
    @Published var isBusy = false
    @Published var errorMessage: String?
    @Published private(set) var transfer: TransferState?

    private let host: SSHHost
    private let credential: SSHCredential
    private let knownHosts: KnownHostsStore
    private let jump: SSHJumpConfig?
    private var client: SFTPClient?
    private var logger: SessionLogger?

    init(host: SSHHost, credential: SSHCredential, knownHosts: KnownHostsStore, jump: SSHJumpConfig? = nil) {
        self.host = host
        self.credential = credential
        self.knownHosts = knownHosts
        self.jump = jump
    }

    var canGoUp: Bool { path != "/" }

    func start(logStore: SessionLogStore) async {
        let target = "\(host.username)@\(host.hostname):\(host.port)"
        let logger = SessionLogger(store: logStore, profileLabel: host.label, target: target, kind: "sftp")
        self.logger = logger
        logger.info("Ouverture d'une session SFTP vers \(target)")
        do {
            let hostID = KnownHostsStore.hostID(hostname: host.hostname, port: host.port)
            let client = try await SFTPClient.connect(
                to: host,
                credential: credential,
                knownHostKey: knownHosts.key(forHostID: hostID),
                jump: jump
            )
            if let learned = await client.learnedHostKey() {
                knownHosts.remember(learned, forHostID: hostID)
                logger.info("Clé hôte mémorisée (TOFU)")
            }
            self.client = client
            path = (try? await client.realPath(".")) ?? "/"
            try await reload()
            status = .ready
            logger.info("Connecté — \(path)")
        } catch {
            status = .failed(error.localizedDescription)
            logger.error(error.localizedDescription)
        }
    }

    func stop() async {
        await client?.disconnect()
        client = nil
        logger?.info("Session SFTP fermée")
        logger?.finish()
    }

    func reload() async throws {
        guard let client else { return }
        isBusy = true
        defer { isBusy = false }
        files = try await client.listDirectory(path)
    }

    func open(_ file: SFTPFile) async {
        guard file.isDirectory else { return }
        path = file.path
        await reloadSafely()
    }

    func goUp() async {
        path = Self.parentPath(of: path)
        await reloadSafely()
    }

    func makeDirectory(named name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard let client, !trimmed.isEmpty else { return }
        await run {
            try await client.makeDirectory(Self.join(self.path, trimmed))
            try await self.reload()
        }
    }

    func delete(_ file: SFTPFile) async {
        guard let client else { return }
        await run {
            if file.isDirectory {
                try await client.removeDirectory(file.path)
            } else {
                try await client.removeFile(file.path)
            }
            try await self.reload()
        }
    }

    /// Télécharge un fichier **en streaming** vers un emplacement temporaire et
    /// retourne son URL, en rapportant la progression.
    func download(_ file: SFTPFile) async -> URL? {
        guard let client else { return nil }
        isBusy = true
        transfer = TransferState(kind: .download, name: file.name, transferred: 0, total: file.size)
        defer { isBusy = false; transfer = nil }
        do {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(file.name)
            try? FileManager.default.removeItem(at: url)
            try await client.downloadFile(at: file.path, to: url, progress: progressHandler())
            logger?.info("Téléchargé : \(file.path)")
            return url
        } catch {
            errorMessage = error.localizedDescription
            logger?.error("Échec téléchargement \(file.path) : \(error.localizedDescription)")
            return nil
        }
    }

    /// Envoie un fichier local **en streaming**, en rapportant la progression.
    func upload(from url: URL) async {
        guard let client else { return }
        let destination = Self.join(path, url.lastPathComponent)
        isBusy = true
        transfer = TransferState(kind: .upload, name: url.lastPathComponent, transferred: 0, total: nil)
        defer { isBusy = false; transfer = nil }
        do {
            let needsScope = url.startAccessingSecurityScopedResource()
            defer { if needsScope { url.stopAccessingSecurityScopedResource() } }
            try await client.uploadFile(from: url, to: destination, progress: progressHandler())
            logger?.info("Envoyé : \(destination)")
            try await reload()
        } catch {
            errorMessage = error.localizedDescription
            logger?.error("Échec envoi \(destination) : \(error.localizedDescription)")
        }
    }

    /// Modifie les permissions POSIX d'un fichier distant (`chmod`).
    func setPermissions(_ mode: UInt32, on file: SFTPFile) async {
        guard let client else { return }
        await run {
            try await client.setPermissions(mode, at: file.path)
            self.logger?.info("chmod \(String(mode, radix: 8)) \(file.path)")
            try await self.reload()
        }
    }

    /// Construit un rappel de progression qui met à jour ``transfer`` sur le
    /// MainActor depuis l'actor SFTP.
    private func progressHandler() -> SFTPTransferProgress {
        { [weak self] transferred, total in
            Task { @MainActor in self?.updateProgress(transferred, total) }
        }
    }

    private func updateProgress(_ transferred: UInt64, _ total: UInt64?) {
        guard var state = transfer else { return }
        state.transferred = transferred
        if let total { state.total = total }
        transfer = state
    }

    private func reloadSafely() async {
        await run { try await self.reload() }
    }

    private func run(_ operation: @escaping () async throws -> Void) async {
        isBusy = true
        defer { isBusy = false }
        do {
            try await operation()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    static func parentPath(of path: String) -> String {
        guard path != "/" else { return "/" }
        let trimmed = path.hasSuffix("/") ? String(path.dropLast()) : path
        let components = trimmed.split(separator: "/")
        guard components.count > 1 else { return "/" }
        return "/" + components.dropLast().joined(separator: "/")
    }

    static func join(_ base: String, _ component: String) -> String {
        base.hasSuffix("/") ? base + component : base + "/" + component
    }
}
