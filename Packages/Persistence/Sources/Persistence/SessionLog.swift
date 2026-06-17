import Foundation
import SwiftData

/// Une ligne de journal de session.
public struct SessionLogEntry: Codable, Sendable, Hashable, Identifiable {
    public enum Level: String, Codable, Sendable {
        case info, warning, error
    }

    public var id = UUID()
    public let timestamp: Date
    public let level: Level
    public let message: String

    public init(timestamp: Date = Date(), level: Level, message: String) {
        self.timestamp = timestamp
        self.level = level
        self.message = message
    }
}

/// Journal d'une session (terminal ou SFTP).
///
/// Stocké **localement** (jamais synchronisé) : les journaux sont propres à
/// l'appareil et peuvent contenir des détails sensibles.
@Model
public final class SessionLog {
    public var id: UUID = UUID()
    public var profileLabel: String = ""
    public var target: String = ""
    /// "terminal" ou "sftp".
    public var kind: String = "terminal"
    public var startedAt: Date = Date()
    public var endedAt: Date?
    public var entries: [SessionLogEntry] = []

    public init(profileLabel: String, target: String, kind: String, startedAt: Date = Date()) {
        self.profileLabel = profileLabel
        self.target = target
        self.kind = kind
        self.startedAt = startedAt
    }
}
