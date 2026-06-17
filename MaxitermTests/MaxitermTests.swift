//
//  MaxitermTests.swift
//  MaxitermTests
//

import Core
import Testing

struct MaxitermTests {
    @Test func validHostPassesValidation() {
        let host = SSHHost(label: "Demo", hostname: "example.com", username: "root")
        #expect(host.isValid)
    }

    @Test func invalidPortFailsValidation() {
        let host = SSHHost(label: "Demo", hostname: "example.com", port: 0, username: "root")
        #expect(!host.isValid)
    }

    @Test func credentialNeverLeaksSecretInDescription() {
        let credential = SSHCredential.password("s3cr3t")
        #expect(!credential.description.contains("s3cr3t"))
    }
}
