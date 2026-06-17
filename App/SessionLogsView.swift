import Persistence
import SwiftUI

/// Liste des journaux de session enregistrés.
struct SessionLogsView: View {
    @EnvironmentObject private var logStore: SessionLogStore
    @State private var logs: [SessionLog] = []

    var body: some View {
        Group {
            if logs.isEmpty {
                ContentUnavailableView(
                    "Aucun journal",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Les sessions terminal et SFTP apparaîtront ici.")
                )
            } else {
                List {
                    ForEach(logs) { log in
                        NavigationLink {
                            SessionLogDetailView(log: log)
                        } label: {
                            row(for: log)
                        }
                    }
                    .onDelete(perform: delete)
                }
            }
        }
        .navigationTitle("Journaux")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !logs.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Tout effacer", role: .destructive) {
                        logStore.clearAll()
                        reload()
                    }
                }
            }
        }
        .onAppear(perform: reload)
    }

    private func row(for log: SessionLog) -> some View {
        HStack(spacing: 12) {
            Image(systemName: log.kind == "sftp" ? "folder" : "terminal")
                .foregroundStyle(.tint)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(log.profileLabel.isEmpty ? log.target : log.profileLabel)
                    .font(.headline)
                Text(log.startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(log.entries.count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private func reload() {
        logs = (try? logStore.allLogs()) ?? []
    }

    private func delete(_ offsets: IndexSet) {
        for index in offsets where logs.indices.contains(index) {
            logStore.delete(logs[index])
        }
        reload()
    }
}

/// Détail d'un journal : lignes horodatées et colorées par niveau.
struct SessionLogDetailView: View {
    let log: SessionLog

    var body: some View {
        List {
            Section {
                ForEach(log.entries.sorted { $0.timestamp < $1.timestamp }) { entry in
                    HStack(alignment: .top, spacing: 8) {
                        Text(entry.timestamp.formatted(date: .omitted, time: .standard))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 72, alignment: .leading)
                        Text(entry.message)
                            .font(.footnote)
                            .foregroundStyle(color(for: entry.level))
                            .textSelection(.enabled)
                    }
                }
            } header: {
                Text("\(log.target) — \(log.kind)")
            }
        }
        .navigationTitle(log.profileLabel.isEmpty ? log.target : log.profileLabel)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: exportText)
            }
        }
    }

    private var exportText: String {
        let header = "MaxiTerm — \(log.target) (\(log.kind))\n"
            + "\(log.startedAt.formatted())\n\n"
        let lines = log.entries
            .sorted { $0.timestamp < $1.timestamp }
            .map { entry in
                let time = entry.timestamp.formatted(date: .omitted, time: .standard)
                return "[\(time)] \(entry.level.rawValue.uppercased()) \(entry.message)"
            }
            .joined(separator: "\n")
        return header + lines
    }

    private func color(for level: SessionLogEntry.Level) -> Color {
        switch level {
        case .info: return .primary
        case .warning: return .orange
        case .error: return .red
        }
    }
}
