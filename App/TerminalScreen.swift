import SwiftUI
import TerminalUI

/// Contenu d'un onglet : surface terminal + barre de touches spéciales. Le cycle
/// de vie de la session est géré par ``TerminalTabsModel`` ; le thème suit le
/// réglage partagé `terminalThemeID`.
struct TerminalSessionView: View {
    @ObservedObject var viewModel: SessionViewModel
    @AppStorage("terminalThemeID") private var themeID = TerminalTheme.defaultDark.id

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                TerminalSurface(emulator: viewModel.emulator)
                if case let .failed(message) = viewModel.status {
                    errorBanner(message)
                }
            }
            SpecialKeysBar(emulator: viewModel.emulator)
        }
        .onAppear { applyTheme(themeID) }
        .onChange(of: themeID) { _, newValue in applyTheme(newValue) }
    }

    private func applyTheme(_ id: String) {
        viewModel.emulator.apply(theme: TerminalTheme.theme(id: id))
    }

    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(.callout)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.red, in: RoundedRectangle(cornerRadius: 10))
            .padding()
    }
}
