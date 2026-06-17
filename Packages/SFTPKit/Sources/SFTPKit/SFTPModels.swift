import Foundation

/// Rappel de progression d'un transfert : octets transférés et taille totale
/// (si connue). Appelé après chaque bloc.
public typealias SFTPTransferProgress = @Sendable (_ transferred: UInt64, _ total: UInt64?) -> Void

/// Erreurs de la couche SFTP.
public enum SFTPError: LocalizedError {
    case connectionFailed(String)
    case malformedResponse
    case status(code: UInt32, message: String)

    public var errorDescription: String? {
        switch self {
        case let .connectionFailed(reason):
            return "Connexion SFTP impossible : \(reason)"
        case .malformedResponse:
            return "Réponse SFTP malformée."
        case let .status(code, message):
            let detail = message.isEmpty ? statusName(code) : message
            return "Erreur SFTP : \(detail)"
        }
    }

    private func statusName(_ code: UInt32) -> String {
        switch code {
        case 2: return "fichier introuvable"
        case 3: return "permission refusée"
        case 4: return "échec"
        case 8: return "opération non supportée"
        default: return "code \(code)"
        }
    }
}

/// Entrée de fichier/répertoire distante.
public struct SFTPFile: Identifiable, Hashable, Sendable {
    public var id: String { path }
    public let name: String
    public let path: String
    public let isDirectory: Bool
    public let size: UInt64?
    public let modificationDate: Date?

    public init(name: String, path: String, isDirectory: Bool, size: UInt64?, modificationDate: Date?) {
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
        self.size = size
        self.modificationDate = modificationDate
    }
}
