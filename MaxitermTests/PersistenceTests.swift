//
//  PersistenceTests.swift
//  MaxitermTests
//
//  Exécutés sur simulateur iOS (SwiftData).
//

import Core
import Foundation
import Persistence
import Testing

// Note : la création d'un `ModelContainer` SwiftData n'est pas fiable dans un
// bundle de tests unitaires ; le conteneur est validé au lancement réel de
// l'app (voir vérification au simulateur). Ces tests couvrent le mapping pur.
struct PersistenceTests {
    @Test func profileMapsToValidHost() {
        let profile = SSHProfile(label: "Demo", hostname: "example.com", port: 2222, username: "ubuntu")
        let host = profile.host
        #expect(host.isValid)
        #expect(host.port == 2222)
    }

    @Test func passwordProfileBuildsPasswordCredential() {
        let profile = SSHProfile(label: "Demo", hostname: "example.com", username: "root", authMethod: .password)
        if case let .password(value) = profile.credential(withSecret: "topsecret") {
            #expect(value == "topsecret")
        } else {
            Issue.record("Attendu un credential mot de passe")
        }
    }

    @Test func keyProfileBuildsPrivateKeyCredential() {
        let profile = SSHProfile(label: "Demo", hostname: "example.com", username: "root", authMethod: .privateKey)
        if case let .privateKeyPEM(privateKey, passphrase) = profile.credential(withSecret: "PEM") {
            #expect(privateKey == "PEM")
            #expect(passphrase == nil)
        } else {
            Issue.record("Attendu un credential par clé privée")
        }
    }
}
