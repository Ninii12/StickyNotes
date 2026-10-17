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

    static let defaultColors: [String] = [
        "#FFF59D", "#FFCC80", "#F48FB1", "#81D4FA", "#A5D6A7", "#CE93D8", "#B0BEC5"
    ]

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
            backgroundImage: nil
        )
    }
}
