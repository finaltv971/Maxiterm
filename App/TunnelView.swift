import Core
import Persistence
import SSHKit
import SwiftUI

/// Écran de **tunnel SSH** (port forwarding local) : redirige un port local vers
/// un service distant accessible depuis le serveur.
struct TunnelView: View {
    let host: SSHHost

    @StateObject private var model: TunnelModel
    @State private var remoteHost = "127.0.0.1"
    @State private var remotePort = "5432"
    @State private var localPort = "0"

    init(host: SSHHost, credential: SSHCredential, knownHosts: KnownHostsStore, jump: SSHJumpConfig? = nil) {
        self.host = host
        _model = StateObject(
            wrappedValue: TunnelModel(host: host, credential: credential, knownHosts: knownHosts, jump: jump)
        )
    }

    private var canStart: Bool {
        !remoteHost.trimmingCharacters(in: .whitespaces).isEmpty && Int(remotePort) != nil
    }

    var body: some View {
        Form {
            Section("Destination (vue depuis le serveur)") {
                TextField("Hôte distant", text: $remoteHost)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Port distant", text: $remotePort)
                    .keyboardType(.numberPad)
            }
            Section("Écoute locale") {
                TextField("Port local (0 = auto)", text: $localPort)
                    .keyboardType(.numberPad)
            }
            Section {
                statusRow
            }
        }
        .navigationTitle("Tunnel — \(host.label)")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { Task { await model.stop() } }
    }

    @ViewBuilder
    private var statusRow: some View {
        switch model.status {
        case .idle:
            Button("Démarrer le tunnel") { start() }
                .disabled(!canStart)
        case .connecting:
            HStack { ProgressView().controlSize(.small); Text("Connexion…") }
        case let .active(port):
            VStack(alignment: .leading, spacing: 8) {
                Label("Actif sur 127.0.0.1:\(port)", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Trafic local → \(remoteHost):\(remotePort) via \(host.hostname).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Arrêter", role: .destructive) {
                    Task { await model.stopForward() }
                }
            }
        case let .failed(message):
            VStack(alignment: .leading, spacing: 8) {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Button("Réessayer") { start() }
            }
        }
    }

    private func start() {
        Task {
            await model.start(
                remoteHost: remoteHost.trimmingCharacters(in: .whitespaces),
                remotePort: Int(remotePort) ?? 0,
                localPort: Int(localPort) ?? 0
            )
        }
    }
}
