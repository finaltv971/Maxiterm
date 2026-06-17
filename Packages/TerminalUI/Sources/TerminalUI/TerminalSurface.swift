import SwiftTerm
import SwiftUI

/// Pont SwiftUI ↔ `TerminalView` (UIKit) de SwiftTerm.
///
/// Branche la vue terminal sur un ``TerminalEmulator`` : la saisie clavier et
/// les changements de taille remontent vers l'émulateur ; les octets distants
/// descendent via ``TerminalEmulator/feed(_:)``.
public struct TerminalSurface: UIViewRepresentable {
    private let emulator: TerminalEmulator

    public init(emulator: TerminalEmulator) {
        self.emulator = emulator
    }

    public func makeUIView(context: Context) -> TerminalView {
        let terminalView = TerminalView(frame: .zero)
        terminalView.terminalDelegate = context.coordinator
        emulator.view = terminalView
        emulator.applyThemeToView()
        return terminalView
    }

    public func updateUIView(_ uiView: TerminalView, context: Context) {
        // L'affichage est piloté impérativement via TerminalEmulator.feed ;
        // rien à synchroniser ici.
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(emulator: emulator)
    }

    public final class Coordinator: NSObject, TerminalViewDelegate {
        private let emulator: TerminalEmulator

        init(emulator: TerminalEmulator) {
            self.emulator = emulator
        }

        // SwiftTerm invoque ces callbacks sur le thread principal (UIKit) ; on
        // fait le pont vers l'isolation MainActor de TerminalEmulator.
        public func send(source: TerminalView, data: ArraySlice<UInt8>) {
            MainActor.assumeIsolated {
                emulator.onInput?(Data(data))
            }
        }

        public func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
            MainActor.assumeIsolated {
                emulator.onResize?(newCols, newRows)
            }
        }

        // Méthodes requises du protocole, sans effet au stade MVP.
        public func setTerminalTitle(source: TerminalView, title: String) {}
        public func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
        public func scrolled(source: TerminalView, position: Double) {}
        public func requestOpenLink(source: TerminalView, link: String, params: [String: String]) {}
        public func rangeChanged(source: TerminalView, startY: Int, endY: Int) {}
        public func clipboardCopy(source: TerminalView, content: Data) {}
    }
}
