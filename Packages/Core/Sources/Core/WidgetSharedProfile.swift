import Foundation

/// Métadonnées **non sensibles** d'un profil, partagées avec l'extension Widget
/// via l'App Group. Aucun secret n'y figure — uniquement de quoi afficher et
/// construire le lien d'ouverture (`maxiterm://connect/<id>`).
public struct WidgetSharedProfile: Codable, Sendable, Identifiable {
    public let id: UUID
    public let label: String
    public let subtitle: String

    public init(id: UUID, label: String, subtitle: String) {
        self.id = id
        self.label = label
        self.subtitle = subtitle
    }
}

/// Pont App Group entre l'app et l'extension Widget : l'app écrit la liste des
/// profils récents, le widget la lit.
public enum MaxitermAppGroup {
    public static let identifier = "group.fr.digistream.maxiterm"
    private static let recentProfilesKey = "recentProfiles"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: identifier)
    }

    public static func writeRecentProfiles(_ profiles: [WidgetSharedProfile]) {
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        defaults?.set(data, forKey: recentProfilesKey)
    }

    public static func readRecentProfiles() -> [WidgetSharedProfile] {
        guard
            let data = defaults?.data(forKey: recentProfilesKey),
            let profiles = try? JSONDecoder().decode([WidgetSharedProfile].self, from: data)
        else { return [] }
        return profiles
    }

    /// URL d'ouverture d'une connexion vers un profil depuis le widget.
    public static func connectURL(profileID: UUID) -> URL {
        URL(string: "maxiterm://connect/\(profileID.uuidString)")!
    }
}
