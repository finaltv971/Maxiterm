# fastlane

Squelette d'automatisation build/déploiement. **Non câblé** à un compte Apple
Developer pour l'instant — aucun secret n'est versionné.

## Lanes

| Lane | Rôle |
|---|---|
| `fastlane test` | Régénère le projet (XcodeGen) puis lance les tests (`scan`). |
| `fastlane build` | Build d'archive App Store (`gym`). Signature à activer via `match`. |
| `fastlane beta` | Build + envoi TestFlight (`pilot`) — à activer ultérieurement. |

## À configurer avant un vrai déploiement

1. Apple Developer Program + Bundle ID `fr.digistream.maxiterm` réservé.
2. `match` (dépôt de certificats chiffré) ou signature manuelle.
3. Clé API App Store Connect stockée en secret GitHub Actions (jamais commitée).

Voir la documentation : https://docs.fastlane.tools
