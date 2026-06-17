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

    /// Schéma d'URL d'ouverture de l'app depuis le widget.
    public static let urlScheme = "maxiterm"
    public static let connectHost = "connect"

    /// URL d'ouverture d'une connexion vers un profil depuis le widget,
    /// construite via `URLComponents` (pas de parsing de chaîne, pas de
    /// force-unwrap dynamique).
    public static func connectURL(profileID: UUID) -> URL {
        var components = URLComponents()
        components.scheme = urlScheme
        components.host = connectHost
        components.path = "/\(profileID.uuidString)"
        // Repli défensif : littéral statique, valide par construction.
        return components.url ?? URL(string: "\(urlScheme)://\(connectHost)")!
    }
}
