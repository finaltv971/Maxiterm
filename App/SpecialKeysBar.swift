import SwiftUI
import TerminalUI

/// Barre horizontale de touches spéciales absentes du clavier iOS (Esc, Tab,
/// Ctrl-*, flèches, navigation). Chaque touche injecte sa séquence dans la
/// session via ``TerminalEmulator``.
struct SpecialKeysBar: View {
    let emulator: TerminalEmulator

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                key("esc") { emulator.send([0x1B]) }
                key("tab") { emulator.send([0x09]) }
                key("^C") { emulator.send([0x03]) }
                key("^D") { emulator.send([0x04]) }
                key("^Z") { emulator.send([0x1A]) }
                key("^L") { emulator.send([0x0C]) }
                key("^R") { emulator.send([0x12]) }
                key("|") { emulator.send([UInt8(ascii: "|")]) }
                key("~") { emulator.send([UInt8(ascii: "~")]) }
                key("/") { emulator.send([UInt8(ascii: "/")]) }
                key("-") { emulator.send([UInt8(ascii: "-")]) }
                symbolKey("arrow.left") { emulator.sendArrow(.left) }
                symbolKey("arrow.up") { emulator.sendArrow(.up) }
                symbolKey("arrow.down") { emulator.sendArrow(.down) }
                symbolKey("arrow.right") { emulator.sendArrow(.right) }
                key("Home") { emulator.send([0x1B, UInt8(ascii: "["), UInt8(ascii: "H")]) }
                key("End") { emulator.send([0x1B, UInt8(ascii: "["), UInt8(ascii: "F")]) }
                key("PgUp") { emulator.send([0x1B, UInt8(ascii: "["), UInt8(ascii: "5"), UInt8(ascii: "~")]) }
                key("PgDn") { emulator.send([0x1B, UInt8(ascii: "["), UInt8(ascii: "6"), UInt8(ascii: "~")]) }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .background(.thinMaterial)
    }

    private func key(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(.footnote, design: .monospaced))
                .frame(minWidth: 34)
                .padding(.vertical, 7)
                .padding(.horizontal, 8)
        }
        .buttonStyle(.bordered)
        .tint(.secondary)
    }

    private func symbolKey(_ systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.footnote)
                .frame(minWidth: 34)
                .padding(.vertical, 7)
                .padding(.horizontal, 6)
        }
        .buttonStyle(.bordered)
        .tint(.secondary)
    }
}
