import Foundation

/// Petit utilitaire d'enregistrement d'événements pour une session donnée.
///
/// Créé par l'écran (qui possède le ``SessionLogStore``) et passé au view model.
@MainActor
public final class SessionLogger {
    private let store: SessionLogStore
    private let log: SessionLog

    public init(store: SessionLogStore, profileLabel: String, target: String, kind: String) {
        self.store = store
        self.log = store.begin(profileLabel: profileLabel, target: target, kind: kind)
    }

    public func info(_ message: String) {
        store.append(SessionLogEntry(level: .info, message: message), to: log)
    }

    public func warning(_ message: String) {
        store.append(SessionLogEntry(level: .warning, message: message), to: log)
    }

    public func error(_ message: String) {
        store.append(SessionLogEntry(level: .error, message: message), to: log)
    }

    public func finish() {
        store.finish(log)
    }
}
