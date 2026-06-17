import Core
import Foundation
import Persistence
import SSHKit

/// Un onglet de terminal : une cible SSH et le view model de sa session vivante.
@MainActor
final class TerminalTab: Identifiable {
    let id = UUID()
    let host: SSHHost
    let credential: SSHCredential
    let jump: SSHJumpConfig?
    let viewModel = SessionViewModel()

    var title: String { host.label }

    init(host: SSHHost, credential: SSHCredential, jump: SSHJumpConfig?) {
        self.host = host
        self.credential = credential
        self.jump = jump
    }
}

/// Gère plusieurs sessions terminal concurrentes sous forme d'onglets. Chaque
/// onglet garde sa session active même quand il n'est pas affiché.
@MainActor
final class TerminalTabsModel: ObservableObject {
    @Published private(set) var tabs: [TerminalTab] = []
    @Published var selectedID: TerminalTab.ID?

    var isEmpty: Bool { tabs.isEmpty }

    var selectedTab: TerminalTab? {
        tabs.first { $0.id == selectedID }
    }

    /// Ouvre un nouvel onglet et démarre sa session.
    func open(
        host: SSHHost,
        credential: SSHCredential,
        jump: SSHJumpConfig? = nil,
        knownHosts: KnownHostsStore,
        logStore: SessionLogStore
    ) {
        let tab = TerminalTab(host: host, credential: credential, jump: jump)
        tabs.append(tab)
        selectedID = tab.id
        tab.viewModel.start(
            host: host,
            credential: credential,
            knownHosts: knownHosts,
            logStore: logStore,
            jump: jump
        )
    }

    /// Ferme un onglet (et arrête sa session).
    func close(_ id: TerminalTab.ID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[index].viewModel.stop()
        tabs.remove(at: index)
        if selectedID == id {
            selectedID = tabs.last?.id
        }
    }

    /// Ferme tous les onglets (à la fermeture du conteneur).
    func closeAll() {
        for tab in tabs { tab.viewModel.stop() }
        tabs.removeAll()
        selectedID = nil
    }
}
