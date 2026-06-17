# Contribuer à MaxiTerm

Merci de votre intérêt ! MaxiTerm est ouvert et accueillant. Ce guide décrit le
flux de travail et les conventions.

## Avant de commencer

- Lisez le [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).
- Pour une faille de sécurité, suivez [SECURITY.md](SECURITY.md) (jamais d'issue publique).
- Discutez des changements importants dans une **issue** ou une **Discussion** d'abord.

## Mise en place

```bash
brew install xcodegen swiftlint swiftformat
xcodegen generate          # ou : make generate
```

`project.yml` est la **source de vérité** ; ne modifiez jamais le `.xcodeproj`
généré à la main (il n'est pas versionné).

## Flux de travail

1. Forkez et créez une branche : `feat/…`, `fix/…`, `docs/…`.
2. Écrivez le code **et les tests** (Swift Testing — `import Testing`).
3. Avant de pousser, assurez-vous que tout est vert :
   ```bash
   swiftformat .
   swiftlint lint --strict
   xcodebuild -project Maxiterm.xcodeproj -scheme Maxiterm \
     -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
   ```
4. Ouvrez une Pull Request en remplissant le gabarit.

## Conventions de commit

Format **Conventional Commits** :

```
<type>(<scope>): <description>
```

Types : `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `perf`, `ci`, `style`, `build`.
Scopes usuels : `app`, `core`, `sshkit`, `terminalui`, `relay`, `ci`.

## DCO (Developer Certificate of Origin)

MaxiTerm utilise le **DCO** plutôt qu'un CLA. Signez chaque commit :

```bash
git commit -s -m "feat(sshkit): ajoute l'auth Ed25519"
```

Le `-s` ajoute une ligne `Signed-off-by: Votre Nom <email>` attestant que vous
avez le droit de soumettre ce code sous la licence MIT du projet.

## Style de code

- Swift idiomatique : `struct`/valeurs par défaut, `let` plutôt que `var`,
  acteurs pour l'état mutable partagé.
- Beaucoup de petits fichiers, fortement cohésifs (< 400 lignes visées).
- Respecter `.swiftlint.yml` et `.swiftformat`.

## Tests

- Couverture des nouvelles fonctionnalités attendue.
- Pas de réseau dans les tests unitaires (mocker la frontière SSH).
