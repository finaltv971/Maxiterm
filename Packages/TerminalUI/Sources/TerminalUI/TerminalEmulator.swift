import Foundation
import SwiftTerm

/// Façade `@MainActor` au-dessus d'un `TerminalView` SwiftTerm.
///
/// L'appelant (un view model SwiftUI) possède l'émulateur, lui pousse les
/// octets reçus du serveur via ``feed(_:)`` et reçoit la saisie clavier et les
/// changements de taille via ``onInput`` / ``onResize``.
@MainActor
public final class TerminalEmulator {
    /// Vue sous-jacente, attachée par ``TerminalSurface`` lors de sa création.
    weak var view: TerminalView?

    /// Appelé quand l'utilisateur tape : octets à transmettre au serveur.
    public var onInput: ((Data) -> Void)?

    /// Appelé quand la grille du terminal change de dimensions.
    public var onResize: ((_ cols: Int, _ rows: Int) -> Void)?

    /// Thème courant ; ré-appliqué automatiquement quand la vue s'attache.
    public private(set) var theme: TerminalTheme = .defaultDark

    public init() {}

    /// Envoie des octets bruts au serveur, comme une frappe clavier (utilisé par
    /// la barre de touches spéciales).
    public func send(_ bytes: [UInt8]) {
        guard !bytes.isEmpty else { return }
        onInput?(Data(bytes))
    }

    /// Séquences de touches fléchées, en respectant le mode curseur applicatif
    /// (ESC O … en mode application, ESC [ … sinon — ex. vim vs shell).
    public enum ArrowKey: Sendable {
        case up, down, right, left

        fileprivate var finalByte: UInt8 {
            switch self {
            case .up: return UInt8(ascii: "A")
            case .down: return UInt8(ascii: "B")
            case .right: return UInt8(ascii: "C")
            case .left: return UInt8(ascii: "D")
            }
        }
    }

    public func sendArrow(_ key: ArrowKey) {
        let applicationCursor = view?.getTerminal().applicationCursor ?? false
        let prefix: [UInt8] = applicationCursor ? [0x1B, UInt8(ascii: "O")] : [0x1B, UInt8(ascii: "[")]
        send(prefix + [key.finalByte])
    }

    /// Applique un thème (couleurs ANSI, avant-plan, arrière-plan, curseur).
    public func apply(theme: TerminalTheme) {
        self.theme = theme
        applyThemeToView()
    }

    /// Ré-applique le thème courant à la vue (appelé à l'attachement de la vue).
    func applyThemeToView() {
        guard let view else { return }
        view.installColors(theme.palette.map(\.swiftTermColor))
        view.nativeForegroundColor = theme.foreground.uiColor
        view.nativeBackgroundColor = theme.background.uiColor
        view.caretColor = theme.cursor.uiColor
    }

    /// Affiche des octets bruts reçus du flux distant.
    public func feed(_ data: Data) {
        guard !data.isEmpty else { return }
        view?.feed(byteArray: ArraySlice(data))
    }

    /// Dimensions courantes de la grille (cols, rows), ou nil si pas encore prête.
    public var currentSize: (cols: Int, rows: Int)? {
        guard let terminal = view?.getTerminal() else { return nil }
        return (terminal.cols, terminal.rows)
    }
}
