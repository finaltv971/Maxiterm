import Core
import Persistence
import SSHKit
import SwiftData
import SwiftUI
import WidgetKit

/// Écran d'accueil : liste des profils SSH enregistrés, avec connexion directe,
/// édition et suppression.
struct ProfileListView: View {
    @EnvironmentObject private var store: ProfileStore
    @EnvironmentObject private var logStore: SessionLogStore
    @Query(
        sort: [
            SortDescriptor(\SSHProfile.lastUsedAt, order: .reverse),
            SortDescriptor(\SSHProfile.label),
        ]
    )
    private var profiles: [SSHProfile]

    @StateObject private var tabs = TerminalTabsModel()
    @State private var editorMode: ProfileEditorView.Mode?
    @State private var showTerminal = false
    @State private var sftpTarget: SFTPTarget?
    @State private var tunnelTarget: SFTPTarget?
    @State private var showLogs = false
    @State private var showSnippets = false
    @State private var showTipJar = false
    @State private var errorMessage: String?
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        NavigationStack {
            Group {
                if profiles.isEmpty {
                    ContentUnavailableView(
                        "Aucun profil",
                        systemImage: "server.rack",
                        description: Text("Ajoutez un serveur SSH pour commencer.")
                    )
                } else {
                    List {
                        ForEach(profiles) { profile in
                            Button { connect(profile) } label: {
                                ProfileRow(profile: profile)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { delete(profile) } label: {
                                    Label("Supprimer", systemImage: "trash")
                                }
                                Button { editorMode = .edit(profile) } label: {
                                    Label("Modifier", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                            .swipeActions(edge: .leading) {
                                Button { openFiles(profile) } label: {
                                    Label("Fichiers", systemImage: "folder")
                                }
                                .tint(.indigo)
                                Button { openTunnel(profile) } label: {
                                    Label("Tunnel", systemImage: "arrow.left.arrow.right")
                                }
                                .tint(.teal)
                            }
                        }
                    }
                }
            }
            .navigationTitle("MaxiTerm")
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button { showLogs = true } label: {
                        Image(systemName: "doc.text.magnifyingglass")
                    }
                    .accessibilityLabel("Journaux")
                    Button { showSnippets = true } label: {
                        Image(systemName: "text.badge.plus")
                    }
                    .accessibilityLabel("Snippets")
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { showTipJar = true } label: {
                        Image(systemName: "heart")
                    }
                    .accessibilityLabel("Soutenir")
                    Button { editorMode = .create } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Ajouter un profil")
                }
            }
            .navigationDestination(isPresented: $showLogs) {
                SessionLogsView()
            }
            .navigationDestination(isPresented: $showSnippets) {
                SnippetsManagerView()
            }
            .sheet(item: $editorMode) { mode in
                ProfileEditorView(mode: mode)
                    .environmentObject(store)
            }
            .fullScreenCover(isPresented: $showTerminal) {
                TerminalTabsView(model: tabs) { showTerminal = false }
            }
            .navigationDestination(item: $sftpTarget) { target in
                SFTPBrowserView(
                    host: target.host,
                    credential: target.credential,
                    knownHosts: store.knownHosts,
                    jump: target.jump
                )
            }
            .navigationDestination(item: $tunnelTarget) { target in
                TunnelView(
                    host: target.host,
                    credential: target.credential,
                    knownHosts: store.knownHosts,
                    jump: target.jump
                )
            }
            .alert(
                "Erreur",
                isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }),
                presenting: errorMessage
            ) { _ in
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: { message in
                Text(message)
            }
            .sheet(isPresented: $showTipJar) {
                TipJarView()
            }
            .fullScreenCover(isPresented: Binding(
                get: { !hasCompletedOnboarding },
                set: { if $0 { hasCompletedOnboarding = false } }
            )) {
                OnboardingView { hasCompletedOnboarding = true }
            }
            .task { publishRecentProfiles() }
            .onChange(of: profiles.map(\.id)) { _, _ in publishRecentProfiles() }
            .onOpenURL(perform: handleDeepLink)
        }
    }

    /// Publie les métadonnées (non sensibles) des profils récents vers l'App Group
    /// et rafraîchit le widget « Connexion rapide ».
    private func publishRecentProfiles() {
        let shared = profiles.prefix(6).map { profile in
            WidgetSharedProfile(
                id: profile.id,
                label: profile.label.isEmpty ? profile.hostname : profile.label,
                subtitle: "\(profile.username)@\(profile.hostname):\(profile.port)"
            )
        }
        MaxitermAppGroup.writeRecentProfiles(Array(shared))
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Ouvre une session depuis le widget : `maxiterm://connect/<uuid>`.
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == MaxitermAppGroup.urlScheme, url.host == MaxitermAppGroup.connectHost,
              let uuid = UUID(uuidString: url.lastPathComponent),
              let profile = profiles.first(where: { $0.id == uuid })
        else { return }
        connect(profile)
    }

    private func connect(_ profile: SSHProfile) {
        do {
            guard let credential = try store.credential(for: profile) else {
                errorMessage = "Aucun secret enregistré pour ce profil."
                return
            }
            store.markUsed(profile)
            tabs.open(
                host: profile.host,
                credential: credential,
                jump: store.jumpConfig(for: profile),
                knownHosts: store.knownHosts,
                logStore: logStore
            )
            showTerminal = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func openFiles(_ profile: SSHProfile) {
        do {
            guard let credential = try store.credential(for: profile) else {
                errorMessage = "Aucun secret enregistré pour ce profil."
                return
            }
            store.markUsed(profile)
            sftpTarget = SFTPTarget(
                host: profile.host,
                credential: credential,
                jump: store.jumpConfig(for: profile)
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func openTunnel(_ profile: SSHProfile) {
        do {
            guard let credential = try store.credential(for: profile) else {
                errorMessage = "Aucun secret enregistré pour ce profil."
                return
            }
            store.markUsed(profile)
            tunnelTarget = SFTPTarget(
                host: profile.host,
                credential: credential,
                jump: store.jumpConfig(for: profile)
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete(_ profile: SSHProfile) {
        do {
            try store.delete(profile)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Cible de navigation pour l'ouverture d'un navigateur SFTP.
struct SFTPTarget: Identifiable, Hashable {
    let id = UUID()
    let host: SSHHost
    let credential: SSHCredential
    let jump: SSHJumpConfig?

    static func == (lhs: SFTPTarget, rhs: SFTPTarget) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Ligne de profil : libellé + cible + méthode d'authentification.
private struct ProfileRow: View {
    let profile: SSHProfile

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: profile.authMethod == .privateKey ? "key.fill" : "lock.fill")
                .foregroundStyle(.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.label.isEmpty ? profile.hostname : profile.label)
                    .font(.headline)
                Text("\(profile.username)@\(profile.hostname):\(profile.port)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}
