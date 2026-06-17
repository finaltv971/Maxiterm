import Foundation
import SwiftData

/// Persistance **locale** des journaux de session (conteneur SwiftData distinct,
/// sans CloudKit).
@MainActor
public final class SessionLogStore: ObservableObject {
    public let container: ModelContainer

    public init(container: ModelContainer) {
        self.container = container
    }

    public static func makeDefault() throws -> SessionLogStore {
        SessionLogStore(container: try ModelContainer(for: SessionLog.self))
    }

    public static func makeInMemory() throws -> SessionLogStore {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return SessionLogStore(container: try ModelContainer(for: SessionLog.self, configurations: configuration))
    }

    private var context: ModelContext { container.mainContext }

    /// Tous les journaux, plus récents d'abord.
    public func allLogs() throws -> [SessionLog] {
        try context.fetch(FetchDescriptor<SessionLog>(sortBy: [SortDescriptor(\.startedAt, order: .reverse)]))
    }

    /// Démarre un nouveau journal.
    public func begin(profileLabel: String, target: String, kind: String) -> SessionLog {
        let log = SessionLog(profileLabel: profileLabel, target: target, kind: kind)
        context.insert(log)
        try? context.save()
        return log
    }

    public func append(_ entry: SessionLogEntry, to log: SessionLog) {
        log.entries.append(entry)
        try? context.save()
    }

    public func finish(_ log: SessionLog) {
        log.endedAt = Date()
        try? context.save()
    }

    public func delete(_ log: SessionLog) {
        context.delete(log)
        try? context.save()
    }

    public func clearAll() {
        try? context.delete(model: SessionLog.self)
        try? context.save()
    }
}
