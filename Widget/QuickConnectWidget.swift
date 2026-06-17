import Core
import SwiftUI
import WidgetKit

/// Entrée de timeline : la liste des profils récents partagés par l'app.
struct QuickConnectEntry: TimelineEntry {
    let date: Date
    let profiles: [WidgetSharedProfile]
}

/// Fournit la liste des profils récents depuis l'App Group. Les timelines sont
/// rechargées par l'app (WidgetCenter) quand les profils changent.
struct QuickConnectProvider: TimelineProvider {
    private static let sample = [
        WidgetSharedProfile(id: UUID(), label: "Exemple", subtitle: "utilisateur@mon-serveur:22"),
        WidgetSharedProfile(id: UUID(), label: "Mini-PC", subtitle: "admin@mon-nas:22"),
    ]

    func placeholder(in context: Context) -> QuickConnectEntry {
        QuickConnectEntry(date: .now, profiles: Self.sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickConnectEntry) -> Void) {
        let profiles = context.isPreview ? Self.sample : MaxitermAppGroup.readRecentProfiles()
        completion(QuickConnectEntry(date: .now, profiles: profiles))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickConnectEntry>) -> Void) {
        let entry = QuickConnectEntry(date: .now, profiles: MaxitermAppGroup.readRecentProfiles())
        completion(Timeline(entries: [entry], policy: .never))
    }
}

/// Widget « Connexion rapide » : ouvre une session vers un profil récent.
struct QuickConnectWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "QuickConnect", provider: QuickConnectProvider()) { entry in
            QuickConnectView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Connexion rapide")
        .description("Ouvre une session SSH vers un profil récent.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct QuickConnectView: View {
    @Environment(\.widgetFamily) private var family
    let entry: QuickConnectEntry

    private var maxCount: Int { family == .systemSmall ? 2 : 4 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "terminal.fill").foregroundStyle(.green)
                Text("MaxiTerm").font(.caption.bold())
                Spacer()
            }

            if entry.profiles.isEmpty {
                Spacer()
                Text("Aucun profil")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ForEach(entry.profiles.prefix(maxCount)) { profile in
                    Link(destination: MaxitermAppGroup.connectURL(profileID: profile.id)) {
                        rowView(profile)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func rowView(_ profile: WidgetSharedProfile) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "bolt.horizontal.circle.fill")
                .foregroundStyle(.tint)
                .font(.footnote)
            VStack(alignment: .leading, spacing: 1) {
                Text(profile.label).font(.footnote).lineLimit(1)
                if family != .systemSmall {
                    Text(profile.subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
    }
}
