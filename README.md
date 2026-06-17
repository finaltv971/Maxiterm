# MaxiTerm

**Le client SSH / SFTP / remote pour iPhone & iPad — entièrement open source, sans abonnement et sans fonction verrouillée.**

> 100% gratuit · toutes les fonctions incluses · sources auditables · zéro tracking · zéro pub.

MaxiTerm est un client de terminal pour iOS/iPadOS. Contrairement aux solutions
du marché qui réservent les fonctions avancées derrière un paywall, **toutes**
les fonctionnalités de MaxiTerm sont gratuites et le resteront. Le financement
repose sur les dons et un éventuel service de relais hébergé (optionnel, non
bloquant) — jamais sur le verrouillage de fonctions. Voir
[`docs/STRATEGY.md`](docs/STRATEGY.md) si présent.

## État du projet

🚧 **En développement actif.** Aujourd'hui, MaxiTerm sait :

- gérer **plusieurs profils SSH** persistés (SwiftData), secrets en **Keychain** ;
- s'authentifier par **mot de passe** ou **clé Ed25519/ECDSA** (OpenSSH, y
  compris **chiffrée par phrase de passe** — bcrypt-pbkdf + AES-CTR/CBC, 100% Apple) ;
- ouvrir des **sessions SSH interactives** (PTY + shell) en **onglets multiples**,
  avec **barre de touches spéciales** (Esc, Ctrl, flèches…) et **thèmes** ;
- parcourir les fichiers distants en **SFTP** (lister, transférer **en streaming**
  avec progression, `chmod`, créer/supprimer un dossier, renommer) — implémentation
  **maison** du protocole ;
- se connecter **à travers un jump host** (ProxyJump) et ouvrir des **tunnels**
  (port forwarding local), générer des **clés Ed25519** dans l'app ;
- **synchroniser** secrets (trousseau **iCloud**) et profils (**CloudKit**) entre
  appareils — retrouver ses éléments en changeant d'iPhone/iPad ;
- **consulter les journaux** de chaque session (terminal et SFTP), avec export ;
- profiter d'une app **localisée** (fr, en, es, it, pt), avec **onboarding**,
  **icône**, manifeste de confidentialité et **tip jar** facultatif (sans déblocage) ;
- le tout sur une couche SSH/SFTP **100% Apple** (`swift-nio-ssh`), auditable.

Roadmap immédiate : clés en **Secure Enclave**, jump hosts, tunnels,
génération de clés, transferts SFTP en streaming.

## Architecture

Monorepo modulaire piloté par **XcodeGen** (`project.yml` est la source de
vérité ; le `.xcodeproj` est généré et n'est pas versionné).

```
App/                 cible iOS/iPadOS (SwiftUI)
Packages/
  Core/              modèles immuables (SSHHost, SSHCredential)
  Persistence/       profils SwiftData + secrets Keychain (ProfileStore)
  SSHKit/            couche SSH sur swift-nio-ssh (Apple) — PTY/shell, clé, sous-systèmes
  SFTPKit/           client SFTP v3 « maison » sur SSHKit
  TerminalUI/        pont SwiftUI ↔ SwiftTerm
Relay/               serveur de relais auto-hébergeable (à venir, open source)
```

| Dépendance | Rôle | Licence |
|---|---|---|
| [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) | émulateur terminal | MIT |
| [swift-nio-ssh](https://github.com/apple/swift-nio-ssh) | SSH bas niveau | Apache-2.0 |
| [swift-nio](https://github.com/apple/swift-nio) | I/O réseau | Apache-2.0 |

Détail complet : [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md).

## Compiler depuis les sources

Prérequis : **Xcode 26+**, [Homebrew](https://brew.sh).

```bash
# 1. Outils
brew install xcodegen swiftlint swiftformat

# 2. Générer le projet Xcode (le .xcodeproj est généré, jamais commité)
xcodegen generate        # ou : make generate

# 3. Construire & tester
xcodebuild -project Maxiterm.xcodeproj -scheme Maxiterm \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

> Le binaire de l'App Store est reconstructible depuis le tag Git correspondant :
> « le binaire = les sources ».

### Tests bout-en-bout (serveur SSH réel)

Les tests d'intégration SSH/SFTP/tunnel/jump host sont ignorés par défaut et
s'activent via des variables d'environnement pointant vers un vrai serveur :

```bash
export MAXITERM_SSH_E2E_KEY=/chemin/vers/cle_privee_ed25519   # clé autorisée côté serveur
export MAXITERM_SSH_E2E_HOST=127.0.0.1                        # défaut : 127.0.0.1
export MAXITERM_SSH_E2E_PORT=22                               # défaut : 22
export MAXITERM_SSH_E2E_USER="$USER"                          # défaut : utilisateur courant
( cd Packages/SSHKit && swift test )   # SSH, tunnel direct-tcpip, jump host, shell
( cd Packages/SFTPKit && swift test )  # SFTP : upload/download streaming, chmod, stat
```

## Limitations connues (MVP)

- **Validation de clé hôte** : **TOFU** (mémorisée à la 1re connexion, refus en
  cas de changement). Un prompt interactif à la première connexion viendra ensuite.
- **Clés** : clés OpenSSH **Ed25519 et ECDSA** importables, **chiffrées ou non**
  (phrase de passe via bcrypt-pbkdf + AES-CTR/CBC, déchiffrement 100% Apple).
- **Non supporté en amont** : `swift-nio-ssh` ne propose ni clé **RSA** côté
  client, ni **keyboard-interactive** (2FA/OTP) — non implémentables sans forker
  la bibliothèque (ce que le projet refuse pour préserver la confiance).

## Conformité export (chiffrement)

MaxiTerm embarque du chiffrement SSH (non exempt par défaut). Le projet revendique
l'usage de **protocoles standard** et la mise à disposition **publique du code
source de chiffrement** (exemption EAR §740.13(e) — License Exception TSU). La clé
`ITSAppUsesNonExemptEncryption` est renseignée à `true` dans `Info.plist` et
l'exemption est déclarée à la soumission. Vérifier les exigences BIS/Apple à jour
au moment de chaque soumission.

## Contribuer

Lire [CONTRIBUTING.md](CONTRIBUTING.md). Les contributions passent par le **DCO**
(`Signed-off-by`), pas de CLA. Politique de sécurité : [SECURITY.md](SECURITY.md).

## Licence

[MIT](LICENSE) © 2026 Anthony BAUCAL (DigiStream).
