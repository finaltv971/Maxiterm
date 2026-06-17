# Politique de sécurité

MaxiTerm manipule des **clés SSH, des mots de passe et des sessions distantes**.
La sécurité est une priorité de premier ordre. Cette politique décrit comment
signaler une vulnérabilité et l'état actuel des protections.

## Signaler une vulnérabilité

**Ne pas** ouvrir d'issue publique pour une faille de sécurité.

- Envoyez un e-mail à **support@digistream.fr** avec le préfixe `[SECURITY]`.
- Ou utilisez les **GitHub Security Advisories** (« Report a vulnerability »).

Merci d'inclure : description, impact, étapes de reproduction, version/commit,
et toute suggestion de correctif. Nous visons un **premier accusé de réception
sous 72 h** et une coordination de divulgation responsable.

## Périmètre

Sont particulièrement concernés :

- la gestion des secrets (mots de passe, futures clés privées) ;
- la couche SSH (`SSHKit`) et la validation des clés hôtes ;
- toute fuite de données sensibles (journaux, presse-papiers, captures).

## Limitations connues (état MVP)

> Ces points sont **assumés et documentés** au stade actuel du MVP. Ne pas
> utiliser MaxiTerm pour des accès sensibles tant qu'ils ne sont pas résolus.

| Sujet | État | Cible |
|---|---|---|
| Validation de clé hôte | **TOFU** : mémorisée à la 1re connexion, **rejet sur changement** (anti-MITM), empreinte SHA256 affichée, réinitialisable par hôte | prompt interactif à la 1re connexion |
| Stockage des secrets | **Keychain** (mots de passe et clés privées) | Secure Enclave |
| Authentification par clé | **Ed25519 + ECDSA** (nistp256/384/521), OpenSSH non chiffrée | clés chiffrées (passphrase), Secure Enclave |
| Journalisation | aucune fuite de secret par conception (`SSHCredential` masqué) | audit continu |

## Bonnes pratiques de conception

- Aucune valeur de `SSHCredential` n'est journalisée (sa description est masquée).
- Couche SSH bâtie **exclusivement** sur des paquets Apple officiels et
  auditables (`swift-nio-ssh`, `swift-crypto`) — aucun fork tiers.
- App Transport Security (ATS) laissé activé par défaut.

## Divulgation

Après correctif, un avis sera publié (GitHub Security Advisory + CHANGELOG), en
créditant le rapporteur s'il le souhaite.
