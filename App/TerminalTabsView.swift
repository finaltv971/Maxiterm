import Core
import Persistence
import SSHKit
import SwiftData
import SwiftUI
import TerminalUI

/// Conteneur multi-onglets de sessions terminal : barre d'onglets, sélection de
/// thème, ajout d'une nouvelle session, fermeture.
struct TerminalTabsView: View {
    @ObservedObject var model: TerminalTabsModel
    let onDismiss: () -> Void

    @EnvironmentObject private var store: ProfileStore
    @EnvironmentObject private var logStore: SessionLogStore
    @AppStorage("terminalThemeID") private var themeID = TerminalTheme.defaultDark.id
    @State private var showPicker = false
    @State private var showCommandBar = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                tabStrip
                Divider()
                sessions
            }
            .navigationTitle(model.selectedTab?.title ?? "Terminal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .safeAreaInset(edge: .bottom) {
                if showCommandBar {
                    CommandBar(model: model)
                }
            }
            .sheet(isPresented: $showPicker) {
                TerminalProfilePicker { host, credential, jump in
                    showPicker = false
                    open(host: host, credential: credential, jump: jump)
                }
            }
            .onChange(of: model.tabs.isEmpty) { _, empty in
                if empty { onDismiss() }
            }
        }
    }

    private var tabStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(model.tabs) { tab in
                    TabChip(
                        tab: tab,
                        isSelected: tab.id == model.selectedID,
                        onSelect: { model.selectedID = tab.id },
                        onClose: { model.close(tab.id) }
                    )
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .background(.bar)
    }

    private var sessions: some View {
        ZStack {
            ForEach(model.tabs) { tab in
                TerminalSessionView(viewModel: tab.viewModel)
                    .opacity(tab.id == model.selectedID ? 1 : 0)
                    .allowsHitTesting(tab.id == model.selectedID)
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Fermer") {
                model.closeAll()
                onDismiss()
            }
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            if let tab = model.selectedTab {
                TabStatusBadge(viewModel: tab.viewModel)
            }
            Button { showCommandBar.toggle() } label: {
                Image(systemName: showCommandBar ? "keyboard.chevron.compact.down" : "command")
            }
            .accessibilityLabel("Barre de commande (MultiExec / snippets)")
            themeMenu
            Button { showPicker = true } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel("Nouvel onglet")
        }
    }

    private var themeMenu: some View {
        Menu {
            Picker("Thème", selection: $themeID) {
                ForEach(TerminalTheme.all) { theme in
                    Text(theme.name).tag(theme.id)
                }
            }
        } label: {
            Image(systemName: "paintpalette")
        }
        .accessibilityLabel("Thème du terminal")
    }

    private func open(host: SSHHost, credential: SSHCredential, jump: SSHJumpConfig?) {
        model.open(
            host: host,
            credential: credential,
            jump: jump,
            knownHosts: store.knownHosts,
            logStore: logStore
        )
    }
}

/// Pastille d'onglet : titre, état de connexion et bouton de fermeture.
private struct TabChip: View {
    @ObservedObject var viewModel: SessionViewModel
    let title: String
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    init(tab: TerminalTab, isSelected: Bool, onSelect: @escaping () -> Void, onClose: @escaping () -> Void) {
        self.viewModel = tab.viewModel
        self.title = tab.title
        self.isSelected = isSelected
        self.onSelect = onSelect
        self.onClose = onClose
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)
            Text(title)
                .font(.footnote)
                .lineLimit(1)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            isSelected ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.12),
            in: Capsule()
        )
        .overlay(
            Capsule().strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 1)
        )
        .contentShape(Capsule())
        .onTapGesture(perform: onSelect)
    }

    private var statusColor: Color {
        switch viewModel.status {
        case .connecting: return .orange
        case .connected: return .green
        case .closed: return .secondary
        case .failed: return .red
        }
    }
}

/// Badge d'état de la session sélectionnée, dans la barre d'outils.
private struct TabStatusBadge: View {
    @ObservedObject var viewModel: SessionViewModel

    var body: some View {
        switch viewModel.status {
        case .connecting:
            ProgressView().controlSize(.small)
        case .connected:
            Image(systemName: "circle.fill").foregroundStyle(.green).font(.caption2)
        case .closed:
            Image(systemName: "circle.fill").foregroundStyle(.secondary).font(.caption2)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red).font(.caption2)
        }
    }
}

/// Sélecteur de profil pour ouvrir un nouvel onglet depuis le terminal.
private struct TerminalProfilePicker: View {
    @EnvironmentObject private var store: ProfileStore
    @Environment(\.dismiss) private var dismiss
    @Query(sort: [SortDescriptor(\SSHProfile.lastUsedAt, order: .reverse)])
    private var profiles: [SSHProfile]
    @State private var errorMessage: String?

    let onPick: (SSHHost, SSHCredential, SSHJumpConfig?) -> Void

    var body: some View {
        NavigationStack {
            List(profiles) { profile in
                Button {
                    pick(profile)
                } label: {
                    VStack(alignment: .leading) {
                        Text(profile.label.isEmpty ? profile.hostname : profile.label)
                            .font(.headline)
                        Text("\(profile.username)@\(profile.hostname):\(profile.port)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Nouvelle session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
            .alert("Erreur", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            ), presenting: errorMessage) { _ in
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: { Text($0) }
        }
    }

    private func pick(_ profile: SSHProfile) {
        do {
            guard let credential = try store.credential(for: profile) else {
                errorMessage = "Aucun secret enregistré pour ce profil."
                return
            }
            store.markUsed(profile)
            onPick(profile.host, credential, store.jumpConfig(for: profile))
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
