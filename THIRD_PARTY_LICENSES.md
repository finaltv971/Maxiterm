# Licences tierces

MaxiTerm est distribué sous licence MIT (voir [LICENSE](LICENSE)). Il s'appuie
sur des dépendances open source, **toutes permissives** (MIT ou Apache-2.0).
Aucune dépendance sous licence copyleft (GPL/LGPL/AGPL) n'est utilisée, afin de
préserver la compatibilité App Store et la licence permissive du projet.

> Couche SSH **100% Apple** : le chiffrement transite uniquement par les paquets
> officiels `swift-nio-ssh` / `swift-crypto` d'Apple — aucun fork tiers.

## Dépendances directes

| Paquet | Version résolue | Rôle | Licence |
|---|---|---|---|
| [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) | 1.13.0 | Émulateur de terminal (xterm) | MIT |
| [swift-nio-ssh](https://github.com/apple/swift-nio-ssh) | 0.13.0 | Implémentation SSH bas niveau | Apache-2.0 |
| [swift-nio](https://github.com/apple/swift-nio) | 2.101.0 | I/O réseau asynchrone | Apache-2.0 |

## Dépendances transitives

| Paquet | Version | Licence |
|---|---|---|
| [swift-crypto](https://github.com/apple/swift-crypto) | 4.5.0 | Apache-2.0 |
| [swift-asn1](https://github.com/apple/swift-asn1) | 1.7.1 | Apache-2.0 |
| [swift-atomics](https://github.com/apple/swift-atomics) | 1.3.0 | Apache-2.0 |
| [swift-collections](https://github.com/apple/swift-collections) | 1.6.0 | Apache-2.0 |
| [swift-system](https://github.com/apple/swift-system) | 1.7.2 | Apache-2.0 |
| [swift-argument-parser](https://github.com/apple/swift-argument-parser) | 1.8.2 | Apache-2.0 |

## Crédits additionnels (composants embarqués par SwiftTerm)

SwiftTerm peut embarquer ou s'inspirer de travaux tiers, notamment des routines
de référence pour la gestion du terminal. Les attributions correspondantes sont
conservées dans les en-têtes de fichiers de SwiftTerm.

## Obligations Apache-2.0

Les dépendances Apache-2.0 imposent de conserver leurs mentions de droits
d'auteur et leur fichier `NOTICE` le cas échéant : voir [NOTICE](NOTICE).

Les textes complets des licences sont disponibles dans chaque dépôt source lié
ci-dessus et dans le dossier `.build`/SourcePackages après résolution SPM.
