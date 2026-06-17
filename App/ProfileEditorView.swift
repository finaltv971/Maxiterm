import Core
import Persistence
import SSHKit
import SwiftUI
import UIKit

/// Création ou édition d'un profil SSH.
struct ProfileEditorView: View {
    enum Mode: Identifiable {
        case create
        case edit(SSHProfile)

        var id: String {
            switch self {
            case .create: return "create"
            case let .edit(profile): return profile.id.uuidString
            }
        }
    }

    @EnvironmentObject private var store: ProfileStore
    @Environment(\.dismiss) private var dismiss

    let mode: Mode

    @State private var label = ""
    @State private var hostname = ""
    @State private var port = "22"
    @State private var username = ""
    @State private var authMethod: ProfileAuthMethod = .password
    @State private var secret = ""
    @State private var passphrase = ""
    @State private var errorMessage: String?
    @State private var knownHostFingerprint: String?
    @State private var generatedPublicKey: String?

    // Jump host (ProxyJump)
    @State private var useJump = false
    @State private var jumpHostname = ""
    @State private var jumpPort = "22"
    @State private var jumpUsername = ""
    @State private var jumpAuthMethod: ProfileAuthMethod = .password
    @State private var jumpSecret = ""
    @State private var jumpPassphrase = ""

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var draftHost: SSHHost {
        SSHHost(
            label: label,
            hostname: hostname.trimmingCharacters(in: .whitespaces),
            port: Int(port) ?? -1,
            username: username.trimmingCharacters(in: .whitespaces)
        )
    }

    private var canSave: Bool {
        // En édition, un secret vide signifie « conserver l'existant ».
        draftHost.isValid && (isEditing || !secret.isEmpty)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Serveur") {
                    TextField("Libellé (optionnel)", text: $label)
                    TextField("Hôte ou IP", text: $hostname)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    TextField("Port", text: $port)
                        .keyboardType(.numberPad)
                    TextField("Utilisateur", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("Authentification") {
                    Picker("Méthode", selection: $authMethod) {
                        ForEach(ProfileAuthMethod.allCases, id: \.self) { method in
                            Text(method.displayName).tag(method)
                        }
                    }

                    switch authMethod {
                    case .password:
                        SecureField(secretFieldPrompt, text: $secret)
                    case .privateKey:
                        VStack(alignment: .leading, spacing: 6) {
                            Text(secretFieldPrompt)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextEditor(text: $secret)
                                .font(.system(.footnote, design: .monospaced))
                                .frame(minHeight: 120)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        }
                        SecureField(passphrasePrompt, text: $passphrase)
                            .textContentType(.password)
                    }
                }

                if authMethod == .privateKey {
                    KeyGenerationSection(generatedPublicKey: generatedPublicKey, onGenerate: generateKey)
                }

                JumpHostSection(
                    useJump: $useJump,
                    hostname: $jumpHostname,
                    port: $jumpPort,
                    username: $jumpUsername,
                    authMethod: $jumpAuthMethod,
                    secret: $jumpSecret,
                    passphrase: $jumpPassphrase,
                    secretPrompt: jumpSecretPrompt
                )

                if isEditing, let fingerprint = knownHostFingerprint {
                    Section("Clé hôte connue (TOFU)") {
                        Text(fingerprint)
                            .font(.footnote.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                        Button("Réinitialiser la clé hôte connue", role: .destructive) {
                            store.knownHosts.forget(hostID: currentHostID)
                            knownHostFingerprint = nil
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Modifier le profil" : "Nouveau profil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { save() }
                        .disabled(!canSave)
                }
            }
            .onAppear(perform: prefillIfEditing)
            .alert(
                "Erreur",
                isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }),
                presenting: errorMessage
            ) { _ in
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: { message in
                Text(message)
            }
        }
    }

    private var secretFieldPrompt: String {
        switch authMethod {
        case .password:
            return isEditing ? "Mot de passe (laisser vide pour conserver)" : "Mot de passe"
        case .privateKey:
            return isEditing ? "Clé privée (laisser vide pour conserver)" : "Clé privée Ed25519 / ECDSA"
        }
    }

    private var passphrasePrompt: String {
        isEditing
            ? "Phrase de passe (laisser vide pour conserver)"
            : "Phrase de passe (si la clé est chiffrée)"
    }

    /// Phrase de passe à transmettre au store : `nil` (= conserver / aucune)
    /// quand le champ est vide ou hors méthode clé privée.
    private var passphraseToStore: String? {
        guard authMethod == .privateKey, !passphrase.isEmpty else { return nil }
        return passphrase
    }

    private var jumpSecretPrompt: String {
        isEditing ? "Secret du rebond (laisser vide pour conserver)" : "Secret du rebond"
    }

    /// Construit l'entrée jump à transmettre au store (`nil` = ne pas toucher).
    private var jumpInput: JumpInput {
        guard useJump, !jumpHostname.trimmingCharacters(in: .whitespaces).isEmpty else {
            return JumpInput(hostname: "", port: 22, username: "", authMethod: .password)
        }
        let passphraseValue = jumpAuthMethod == .privateKey && !jumpPassphrase.isEmpty ? jumpPassphrase : nil
        return JumpInput(
            hostname: jumpHostname.trimmingCharacters(in: .whitespaces),
            port: Int(jumpPort) ?? 22,
            username: jumpUsername.trimmingCharacters(in: .whitespaces),
            authMethod: jumpAuthMethod,
            secret: jumpSecret.isEmpty ? nil : jumpSecret,
            passphrase: passphraseValue
        )
    }

    private var currentHostID: String {
        KnownHostsStore.hostID(hostname: hostname.trimmingCharacters(in: .whitespaces), port: Int(port) ?? 22)
    }

    private func prefillIfEditing() {
        guard case let .edit(profile) = mode else { return }
        label = profile.label
        hostname = profile.hostname
        port = String(profile.port)
        username = profile.username
        authMethod = profile.authMethod
        useJump = profile.usesJumpHost
        jumpHostname = profile.jumpHostname
        jumpPort = String(profile.jumpPort)
        jumpUsername = profile.jumpUsername
        jumpAuthMethod = profile.jumpAuthMethod
        knownHostFingerprint = store.knownHosts.key(forHostID: currentHostID)
            .map { HostKeyFingerprint.sha256(forOpenSSHKey: $0) }
    }

    private func generateKey() {
        let comment = "\(username.isEmpty ? "maxiterm" : username)@\(hostname.isEmpty ? "maxiterm" : hostname)"
        let key = SSHKeyGenerator.generateEd25519(comment: comment)
        secret = key.privateKeyOpenSSH
        passphrase = ""
        generatedPublicKey = key.publicKeyAuthorizedKey
    }

    private func save() {
        let host = draftHost
        let errors = host.validationErrors()
        guard errors.isEmpty else {
            errorMessage = errors.joined(separator: "\n")
            return
        }

        do {
            switch mode {
            case .create:
                try store.create(
                    label: label,
                    hostname: host.hostname,
                    port: host.port,
                    username: host.username,
                    authMethod: authMethod,
                    secret: secret,
                    passphrase: passphraseToStore,
                    jump: jumpInput
                )
            case let .edit(profile):
                profile.label = label
                profile.hostname = host.hostname
                profile.port = host.port
                profile.username = host.username
                profile.authMethod = authMethod
                try store.update(
                    profile,
                    secret: secret.isEmpty ? nil : secret,
                    passphrase: passphraseToStore,
                    jump: jumpInput
                )
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Section de configuration d'un jump host (ProxyJump) dans l'éditeur de profil.
private struct JumpHostSection: View {
    @Binding var useJump: Bool
    @Binding var hostname: String
    @Binding var port: String
    @Binding var username: String
    @Binding var authMethod: ProfileAuthMethod
    @Binding var secret: String
    @Binding var passphrase: String
    let secretPrompt: String

    var body: some View {
        Section("Jump host (ProxyJump)") {
            Toggle("Passer par un rebond SSH", isOn: $useJump.animation())
            if useJump {
                TextField("Hôte ou IP du rebond", text: $hostname)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                TextField("Port", text: $port)
                    .keyboardType(.numberPad)
                TextField("Utilisateur", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Picker("Méthode", selection: $authMethod) {
                    ForEach(ProfileAuthMethod.allCases, id: \.self) { method in
                        Text(method.displayName).tag(method)
                    }
                }
                switch authMethod {
                case .password:
                    SecureField(secretPrompt, text: $secret)
                case .privateKey:
                    TextEditor(text: $secret)
                        .font(.system(.footnote, design: .monospaced))
                        .frame(minHeight: 80)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    SecureField("Phrase de passe (si chiffrée)", text: $passphrase)
                }
            }
        }
    }
}

/// Section de génération de clé Ed25519 et d'affichage de la clé publique.
private struct KeyGenerationSection: View {
    let generatedPublicKey: String?
    let onGenerate: () -> Void

    var body: some View {
        Section {
            Button(action: onGenerate) {
                Label("Générer une clé Ed25519", systemImage: "key.horizontal")
            }
            Text(
                "Collez une clé privée OpenSSH **Ed25519** ou **ECDSA** (nistp256/384/521), "
                    + "ou générez-en une. Si la clé est protégée, renseignez sa **phrase de "
                    + "passe** (bcrypt-pbkdf + AES-CTR pris en charge)."
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
        }

        if let publicKey = generatedPublicKey {
            Section("Clé publique à installer sur le serveur") {
                Text(publicKey)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                Button {
                    UIPasteboard.general.string = publicKey
                } label: {
                    Label("Copier la clé publique", systemImage: "doc.on.doc")
                }
                Text("Ajoutez-la à `~/.ssh/authorized_keys` du serveur.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
