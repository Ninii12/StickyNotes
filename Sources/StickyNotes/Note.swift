import Foundation
import AppKit

struct Note: Identifiable, Codable, Equatable {
    var id: UUID
    var text: String
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var colorHex: String
    var alwaysOnTop: Bool
    var fontSize: Double
    /// Path of a background image relative to the StickyNotes support directory (e.g. "Images/<uuid>.png").
    /// `nil` renders the plain note color. Optional so older notes.json files still decode.
    var backgroundImage: String?
    /// Font family name shown in the note; `nil` (older notes) means the system font.
    var fontName: String?
    /// Text color as hex; `nil` keeps the default near-black.
    var textColorHex: String?

    static let systemFontName = "system"

    /// Font families offered in the text-style popover. Names must match fonts installed
    /// on macOS; SwiftUI silently falls back to the system font when one is missing.
    static let fontChoices: [String] = [
        "system",
        "Helvetica Neue",
        "Avenir Next",
        "Futura",
        "Georgia",
        "Palatino",
        "Times New Roman",
        "Menlo",
        "Courier New",
        "Marker Felt",
        "Chalkboard SE",
        "Verdana"
    ]

    /// Text colors that stay readable on every pastel background; white is for photos.
    static let defaultTextColors: [String] = [
        "#212121", "#37474F", "#D32F2F", "#C2185B", "#7B1FA2", "#303F9F", "#00796B", "#FFFFFF"
    ]

    var resolvedFontName: String { fontName ?? Note.systemFontName }
    var resolvedTextColor: String { textColorHex ?? Note.defaultTextColors[0] }

    static let defaultColors: [String] = [
        "#FFF9C4", "#FFE0B2", "#F8BBD0", "#B3E5FC", "#C8E6C9", "#E1BEE7", "#CFD8DC"
    ]

    /// Colors from the pre-pastel palette, mapped to their soft equivalents so
    /// existing notes pick up the new look on load.
    private static let legacyColors: [String: String] = [
        "#FFF59D": "#FFF9C4",
        "#FFCC80": "#FFE0B2",
        "#F48FB1": "#F8BBD0",
        "#81D4FA": "#B3E5FC",
        "#A5D6A7": "#C8E6C9",
        "#CE93D8": "#E1BEE7",
        "#B0BEC5": "#CFD8DC"
    ]

    static func pastelColor(for hex: String) -> String {
        legacyColors[hex.uppercased()] ?? hex
    }

    static func makeDefault(at index: Int = 0) -> Note {
        let offset = Double(index * 30)
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 100, y: 100, width: 800, height: 600)
        return Note(
            id: UUID(),
            text: "",
            x: Double(screen.midX) - 150 + offset,
            y: Double(screen.midY) - 120 - offset,
            width: 300,
            height: 240,
            colorHex: defaultColors[index % defaultColors.count],
            alwaysOnTop: true,
            fontSize: 14,
            backgroundImage: nil,
            fontName: nil,
            textColorHex: nil
        )
    }
}
