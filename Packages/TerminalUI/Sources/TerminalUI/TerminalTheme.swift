import SwiftTerm
import UIKit

/// Couleur RGB 8 bits d'un thème de terminal.
public struct TerminalThemeColor: Sendable, Hashable {
    public let red: UInt8
    public let green: UInt8
    public let blue: UInt8

    public init(_ red: UInt8, _ green: UInt8, _ blue: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// Conversion depuis un code hexadécimal « RRGGBB ».
    public init(hex: UInt32) {
        self.init(UInt8((hex >> 16) & 0xFF), UInt8((hex >> 8) & 0xFF), UInt8(hex & 0xFF))
    }

    var uiColor: UIColor {
        UIColor(
            red: CGFloat(red) / 255,
            green: CGFloat(green) / 255,
            blue: CGFloat(blue) / 255,
            alpha: 1
        )
    }

    /// SwiftTerm encode chaque canal sur 16 bits (×257 pour étendre 8→16 bits).
    var swiftTermColor: SwiftTerm.Color {
        SwiftTerm.Color(
            red: UInt16(red) * 257,
            green: UInt16(green) * 257,
            blue: UInt16(blue) * 257
        )
    }
}

/// Thème de terminal : 16 couleurs ANSI + avant-plan, arrière-plan et curseur.
public struct TerminalTheme: Identifiable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let foreground: TerminalThemeColor
    public let background: TerminalThemeColor
    public let cursor: TerminalThemeColor
    public let palette: [TerminalThemeColor] // 16 couleurs ANSI

    public init(
        id: String,
        name: String,
        foreground: TerminalThemeColor,
        background: TerminalThemeColor,
        cursor: TerminalThemeColor,
        palette: [TerminalThemeColor]
    ) {
        self.id = id
        self.name = name
        self.foreground = foreground
        self.background = background
        self.cursor = cursor
        self.palette = palette
    }
}

public extension TerminalTheme {
    /// Thèmes intégrés (libres de droits).
    static let all: [TerminalTheme] = [defaultDark, solarizedDark, solarizedLight, nord, dracula]

    static let defaultDark = TerminalTheme(
        id: "default-dark",
        name: "Sombre (par défaut)",
        foreground: TerminalThemeColor(hex: 0xD0D0D0),
        background: TerminalThemeColor(hex: 0x1E1E1E),
        cursor: TerminalThemeColor(hex: 0xD0D0D0),
        palette: [
            0x000000, 0xCD3131, 0x0DBC79, 0xE5E510, 0x2472C8, 0xBC3FBC, 0x11A8CD, 0xE5E5E5,
            0x666666, 0xF14C4C, 0x23D18B, 0xF5F543, 0x3B8EEA, 0xD670D6, 0x29B8DB, 0xFFFFFF,
        ].map(TerminalThemeColor.init(hex:))
    )

    static let solarizedDark = TerminalTheme(
        id: "solarized-dark",
        name: "Solarized Dark",
        foreground: TerminalThemeColor(hex: 0x839496),
        background: TerminalThemeColor(hex: 0x002B36),
        cursor: TerminalThemeColor(hex: 0x93A1A1),
        palette: [
            0x073642, 0xDC322F, 0x859900, 0xB58900, 0x268BD2, 0xD33682, 0x2AA198, 0xEEE8D5,
            0x002B36, 0xCB4B16, 0x586E75, 0x657B83, 0x839496, 0x6C71C4, 0x93A1A1, 0xFDF6E3,
        ].map(TerminalThemeColor.init(hex:))
    )

    static let solarizedLight = TerminalTheme(
        id: "solarized-light",
        name: "Solarized Light",
        foreground: TerminalThemeColor(hex: 0x657B83),
        background: TerminalThemeColor(hex: 0xFDF6E3),
        cursor: TerminalThemeColor(hex: 0x586E75),
        palette: [
            0x073642, 0xDC322F, 0x859900, 0xB58900, 0x268BD2, 0xD33682, 0x2AA198, 0xEEE8D5,
            0x002B36, 0xCB4B16, 0x586E75, 0x657B83, 0x839496, 0x6C71C4, 0x93A1A1, 0xFDF6E3,
        ].map(TerminalThemeColor.init(hex:))
    )

    static let nord = TerminalTheme(
        id: "nord",
        name: "Nord",
        foreground: TerminalThemeColor(hex: 0xD8DEE9),
        background: TerminalThemeColor(hex: 0x2E3440),
        cursor: TerminalThemeColor(hex: 0xD8DEE9),
        palette: [
            0x3B4252, 0xBF616A, 0xA3BE8C, 0xEBCB8B, 0x81A1C1, 0xB48EAD, 0x88C0D0, 0xE5E9F0,
            0x4C566A, 0xBF616A, 0xA3BE8C, 0xEBCB8B, 0x81A1C1, 0xB48EAD, 0x8FBCBB, 0xECEFF4,
        ].map(TerminalThemeColor.init(hex:))
    )

    static let dracula = TerminalTheme(
        id: "dracula",
        name: "Dracula",
        foreground: TerminalThemeColor(hex: 0xF8F8F2),
        background: TerminalThemeColor(hex: 0x282A36),
        cursor: TerminalThemeColor(hex: 0xF8F8F2),
        palette: [
            0x21222C, 0xFF5555, 0x50FA7B, 0xF1FA8C, 0xBD93F9, 0xFF79C6, 0x8BE9FD, 0xF8F8F2,
            0x6272A4, 0xFF6E6E, 0x69FF94, 0xFFFFA5, 0xD6ACFF, 0xFF92DF, 0xA4FFFF, 0xFFFFFF,
        ].map(TerminalThemeColor.init(hex:))
    )

    static func theme(id: String) -> TerminalTheme {
        all.first { $0.id == id } ?? defaultDark
    }
}
