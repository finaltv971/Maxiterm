# Changelog

Toutes les modifications notables de ce projet sont documentées ici.

Le format s'inspire de [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/)
et le projet suit le [Versionnage Sémantique](https://semver.org/lang/fr/).

## [Non publié]

### Ajouté
- Structure monorepo modulaire pilotée par XcodeGen (`project.yml`).
- Packages SwiftPM : `Core`, `Persistence` (SwiftData + Keychain), `SSHKit`
  (SSH sur `swift-nio-ssh` d'Apple), `SFTPKit` (client SFTP v3 maison),
  `TerminalUI` (pont SwiftUI ↔ SwiftTerm).
- Session SSH interactive (PTY + shell) avec terminal xterm.
- **Profils SSH multiples** persistés (SwiftData) ; secrets en **Keychain**.
- **Authentification par clé Ed25519 et ECDSA** (nistp256/384/521), parsing
  OpenSSH, vérifié contre les vecteurs `ssh-keygen`.
- **Génération de clés Ed25519** dans l'app : création d'une paire de clés au
  format OpenSSH (clé privée stockée au Keychain, clé publique `authorized_keys`
  copiable), 100% swift-crypto. Round-trip vérifié par test.
- **Jump hosts (ProxyJump)** : connexion à une cible **à travers un rebond SSH**
  (session SSH imbriquée dans un canal `direct-tcpip`), avec authentification et
  TOFU propres à chaque saut. Disponible pour le **terminal** et le **SFTP**,
  configurable par profil. Vérifié bout-en-bout contre un vrai serveur.
- **Tunnels (port forwarding local)** : redirige un port local vers un service
  distant accessible depuis le serveur (`direct-tcpip` + écoute TCP locale),
  écran dédié par profil. Vérifié bout-en-bout.
- **Tests bout-en-bout réels** : harnais `swift test` (activable par variables
  d'env) validant SSH, SFTP (upload/download/chmod), tunnel, jump host et terminal
  interactif contre un serveur OpenSSH réel.
- **Clés privées chiffrées** : déchiffrement des clés OpenSSH protégées par phrase
  de passe (KDF **bcrypt-pbkdf** + **AES-CTR/CBC**), implémenté **100% Apple**
  (CommonCrypto + swift-crypto). Les constantes Blowfish sont **générées à partir
  de π** (formule de Machin, entiers exacts) plutôt que transcrites — table
  auditable. Phrase de passe stockée au **trousseau iCloud** (synchronizable).
- **Terminal multi-onglets** : plusieurs sessions SSH simultanées, chacune
  maintenue active en arrière-plan ; barre d'onglets avec état de connexion,
  ajout/fermeture, ouverture d'une nouvelle session par sélecteur de profil.
- **Barre de touches spéciales** : Esc, Tab, Ctrl-C/D/Z/L/R, flèches (respectant
  le mode curseur applicatif), Home/End/PgUp/PgDn, `| ~ / -`.
- **Thèmes de terminal** : Sombre (défaut), Solarized Dark/Light, Nord, Dracula —
  16 couleurs ANSI + avant-plan/arrière-plan/curseur, réglage partagé et persisté.
- **Navigateur de fichiers SFTP** : lister, télécharger, envoyer, créer/supprimer
  un dossier, renommer — protocole SFTP v3 implémenté sur swift-nio-ssh.
- **Transferts SFTP en streaming** : lecture/écriture bloc par bloc directement
  sur disque (plus de chargement complet en mémoire — évite les saturations),
  **barre de progression** (octets / total), et **chmod** (permissions POSIX,
  saisie octale + préréglages 644/600/755/700/777).
- **Synchronisation iCloud** : secrets (mots de passe + clés) via le **trousseau
  iCloud** (items synchronizable) et profils via **SwiftData + CloudKit** (repli
  local si iCloud indisponible) — on retrouve ses éléments en changeant d'appareil.
- **Journaux de session** : chaque session terminal/SFTP est journalisée
  (événements horodatés) et consultable dans l'app ; export texte par partage.
  Stockage **local** (non synchronisé).
- **Icône** de l'app (prompt terminal vert, générée par script CoreGraphics).
- **Onboarding** au premier lancement (philosophie open source + fonctions clés).
- **Tip jar** : pourboires **consommables** facultatifs (StoreKit 2) qui **ne
  débloquent rien** — l'app reste 100% gratuite. Config `.storekit` pour le test.
- **Manifeste de confidentialité** `PrivacyInfo.xcprivacy` : aucun tracking,
  aucune collecte ; API à motif requis déclarées (UserDefaults, horodatage fichier).
- **Internationalisation** : français (source), **anglais, espagnol, italien,
  portugais** — String Catalog (`Localizable.xcstrings`).
- Infrastructure open source : MIT, NOTICE, THIRD_PARTY_LICENSES, SECURITY,
  CONTRIBUTING (DCO), CODE_OF_CONDUCT, CI GitHub Actions.

### Sécurité
- Couche SSH **100% Apple**, sans fork tiers.
- **Validation TOFU des clés hôtes** : mémorisation à la première connexion,
  **rejet en cas de changement** (anti-MITM), empreinte SHA256, réinitialisation
  par hôte depuis l'éditeur de profil.
- Secrets (mots de passe **et** clés privées) stockés dans le **Keychain**.

[Non publié]: https://github.com/digistream/maxiterm/commits/main
