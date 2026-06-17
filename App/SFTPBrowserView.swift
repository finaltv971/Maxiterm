import Core
import Persistence
import SFTPKit
import SSHKit
import SwiftUI
import UniformTypeIdentifiers

/// Navigateur de fichiers SFTP : navigation, téléchargement, envoi, création et
/// suppression.
struct SFTPBrowserView: View {
    let host: SSHHost

    @StateObject private var model: SFTPBrowserModel
    @EnvironmentObject private var logStore: SessionLogStore
    @State private var showImporter = false
    @State private var newFolderName = ""
    @State private var showNewFolderAlert = false
    @State private var shareURL: URL?
    @State private var chmodFile: SFTPFile?

    init(host: SSHHost, credential: SSHCredential, knownHosts: KnownHostsStore, jump: SSHJumpConfig? = nil) {
        self.host = host
        _model = StateObject(
            wrappedValue: SFTPBrowserModel(host: host, credential: credential, knownHosts: knownHosts, jump: jump)
        )
    }

    var body: some View {
        content
            .navigationTitle(host.label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .task { await model.start(logStore: logStore) }
            .onDisappear { Task { await model.stop() } }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.item]) { result in
                if case let .success(url) = result {
                    Task { await model.upload(from: url) }
                }
            }
            .alert("Nouveau dossier", isPresented: $showNewFolderAlert) {
                TextField("Nom", text: $newFolderName)
                Button("Créer") {
                    let name = newFolderName
                    newFolderName = ""
                    Task { await model.makeDirectory(named: name) }
                }
                Button("Annuler", role: .cancel) { newFolderName = "" }
            }
            .alert(
                "Erreur",
                isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } }),
                presenting: model.errorMessage
            ) { _ in
                Button("OK", role: .cancel) { model.errorMessage = nil }
            } message: { Text($0) }
            .sheet(item: $shareURL) { url in
                ShareSheet(items: [url])
            }
            .sheet(item: $chmodFile) { file in
                ChmodSheet(file: file) { mode in
                    chmodFile = nil
                    Task { await model.setPermissions(mode, on: file) }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let transfer = model.transfer {
                    TransferProgressBar(transfer: transfer)
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch model.status {
        case .connecting:
            ProgressView("Connexion SFTP…")
        case let .failed(message):
            ContentUnavailableView {
                Label("Connexion impossible", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            }
        case .ready:
            fileList
        }
    }

    private var fileList: some View {
        List {
            Section {
                ForEach(model.files) { file in
                    fileRow(file)
                }
            } header: {
                Text(model.path).font(.footnote).textCase(nil)
            }
        }
        .overlay {
            if model.files.isEmpty {
                ContentUnavailableView("Dossier vide", systemImage: "folder")
            }
        }
        .refreshable { try? await model.reload() }
    }

    private func fileRow(_ file: SFTPFile) -> some View {
        Button {
            Task { await handleTap(file) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: file.isDirectory ? "folder.fill" : "doc")
                    .foregroundStyle(file.isDirectory ? Color.accentColor : .secondary)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(file.name)
                    if let size = file.size, !file.isDirectory {
                        Text(byteCount(size))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if file.isDirectory {
                    Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
                }
            }
            .contentShape(Rectangle())
        }
        .tint(.primary)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                Task { await model.delete(file) }
            } label: {
                Label("Supprimer", systemImage: "trash")
            }
            Button {
                chmodFile = file
            } label: {
                Label("Permissions", systemImage: "lock.shield")
            }
            .tint(.blue)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            if model.isBusy {
                ProgressView()
            }
            Menu {
                Button { showImporter = true } label: {
                    Label("Envoyer un fichier", systemImage: "arrow.up.doc")
                }
                Button { showNewFolderAlert = true } label: {
                    Label("Nouveau dossier", systemImage: "folder.badge.plus")
                }
            } label: {
                Image(systemName: "plus")
            }
            .disabled(model.status != .ready)
        }
        ToolbarItem(placement: .topBarLeading) {
            Button { Task { await model.goUp() } } label: {
                Image(systemName: "chevron.up")
            }
            .disabled(!model.canGoUp || model.status != .ready)
        }
    }

    private func handleTap(_ file: SFTPFile) async {
        if file.isDirectory {
            await model.open(file)
        } else if let url = await model.download(file) {
            shareURL = url
        }
    }

    private func byteCount(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}

/// Barre de progression d'un transfert SFTP (téléchargement ou envoi).
private struct TransferProgressBar: View {
    let transfer: SFTPBrowserModel.TransferState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: transfer.kind == .download ? "arrow.down.circle" : "arrow.up.circle")
                Text(transfer.name).font(.footnote).lineLimit(1)
                Spacer()
                Text(detail).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            if let fraction = transfer.fraction {
                ProgressView(value: fraction)
            } else {
                ProgressView()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var detail: String {
        let done = ByteCountFormatter.string(fromByteCount: Int64(transfer.transferred), countStyle: .file)
        guard let total = transfer.total else { return done }
        let totalString = ByteCountFormatter.string(fromByteCount: Int64(total), countStyle: .file)
        return "\(done) / \(totalString)"
    }
}

/// Feuille de modification des permissions POSIX (`chmod`) d'un fichier distant.
private struct ChmodSheet: View {
    let file: SFTPFile
    let onApply: (UInt32) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var octal = "644"

    private let presets: [(String, String)] = [
        ("644 — rw-r--r--", "644"),
        ("600 — rw-------", "600"),
        ("755 — rwxr-xr-x", "755"),
        ("700 — rwx------", "700"),
        ("777 — rwxrwxrwx", "777"),
    ]

    private var parsedMode: UInt32? {
        guard !octal.isEmpty, octal.count <= 4, octal.allSatisfy({ ("0" ... "7").contains($0) }) else { return nil }
        return UInt32(octal, radix: 8)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Mode octal") {
                    TextField("ex. 644", text: $octal)
                        .keyboardType(.numberPad)
                        .font(.system(.body, design: .monospaced))
                }
                Section("Préréglages") {
                    ForEach(presets, id: \.1) { label, value in
                        Button(label) { octal = value }
                            .font(.system(.body, design: .monospaced))
                    }
                }
            }
            .navigationTitle(file.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Appliquer") {
                        if let mode = parsedMode { onApply(mode) }
                    }
                    .disabled(parsedMode == nil)
                }
            }
        }
    }
}

/// Permet à `URL` d'être utilisée avec `.sheet(item:)`.
extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

/// Pont vers `UIActivityViewController` pour partager/enregistrer un fichier.
private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
