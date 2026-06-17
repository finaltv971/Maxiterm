import XCTest
@testable import Core

final class SSHHostTests: XCTestCase {
    func testValidHostHasNoErrors() {
        let host = SSHHost(label: "Test", hostname: "example.com", port: 22, username: "root")
        XCTAssertTrue(host.isValid)
        XCTAssertTrue(host.validationErrors().isEmpty)
    }

    func testEmptyHostnameIsInvalid() {
        let host = SSHHost(label: "Test", hostname: "   ", username: "root")
        XCTAssertFalse(host.isValid)
        XCTAssertEqual(host.validationErrors().count, 1)
    }

    func testOutOfRangePortIsInvalid() {
        let host = SSHHost(label: "Test", hostname: "example.com", port: 70000, username: "root")
        XCTAssertFalse(host.isValid)
    }

    func testWithLabelIsImmutable() {
        let host = SSHHost(label: "A", hostname: "example.com", username: "root")
        let renamed = host.withLabel("B")
        XCTAssertEqual(host.label, "A")
        XCTAssertEqual(renamed.label, "B")
        XCTAssertEqual(host.id, renamed.id)
    }

    func testCredentialDescriptionDoesNotLeakSecret() {
        let cred = SSHCredential.password("hunter2")
        XCTAssertFalse(cred.description.contains("hunter2"))
        XCTAssertTrue(cred.hasSecret)
    }
}
