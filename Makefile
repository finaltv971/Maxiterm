# Raccourcis de développement MaxiTerm.
# project.yml est la source de vérité ; le .xcodeproj est généré (non versionné).

SCHEME := Maxiterm
PROJECT := Maxiterm.xcodeproj
DESTINATION ?= platform=iOS Simulator,name=iPhone 17 Pro

.PHONY: bootstrap generate build test lint format clean reset

## Installe les outils requis (Homebrew).
bootstrap:
	brew install xcodegen swiftlint swiftformat

## Génère le projet Xcode depuis project.yml.
generate:
	xcodegen generate

## Construit l'app pour le simulateur.
build: generate
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -skipMacroValidation build

## Lance les tests.
test: generate
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -skipMacroValidation test

## Analyse statique.
lint:
	swiftlint lint --strict

## Formate le code.
format:
	swiftformat .

## Nettoie le projet généré et les artefacts.
clean:
	rm -rf $(PROJECT) .build DerivedData

## Récupération complète si les packages SwiftPM sont corrompus dans Xcode
## (« Missing package product »). À lancer Xcode FERMÉ.
reset:
	@pgrep -x Xcode >/dev/null && echo "⚠️  Ferme Xcode d'abord." && exit 1 || true
	rm -rf ~/Library/Developer/Xcode/DerivedData/Maxiterm-*
	rm -rf ~/Library/Caches/org.swift.swiftpm
	rm -rf $(PROJECT)/project.xcworkspace/xcshareddata/swiftpm
	xcodegen generate
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -resolvePackageDependencies
	@echo "✅ Réinitialisé. Tu peux rouvrir $(PROJECT) dans Xcode."
