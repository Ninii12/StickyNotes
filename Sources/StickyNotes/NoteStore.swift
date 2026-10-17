import Foundation
import Combine
import AppKit

@MainActor
final class NoteStore: ObservableObject {
    @Published var notes: [Note] = []

    private let fileURL: URL
    private var saveTimer: Timer?

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = support.appendingPathComponent("StickyNotes", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("notes.json")
    }

    func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode([Note].self, from: data)
            notes = decoded
        } catch {
            print("Failed to load notes: \(error)")
        }
    }

    func scheduleSave() {
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.saveNow()
            }
        }
    }

    func saveNow() {
        do {
            let data = try JSONEncoder().encode(notes)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save notes: \(error)")
        }
    }

    func addNote() -> Note {
        let note = Note.makeDefault(at: notes.count)
        notes = notes + [note]
        saveNow()
        return note
    }

    private func mutate(_ id: UUID, _ transform: (inout Note) -> Void) {
        guard let idx = notes.firstIndex(where: { $0.id == id }) else { return }
        var copy = notes
        transform(&copy[idx])
        notes = copy
    }

    func updateText(_ id: UUID, _ text: String) {
        mutate(id) { $0.text = text }
        scheduleSave()
    }

    func setColor(_ id: UUID, _ hex: String) {
        mutate(id) { $0.colorHex = hex }
        scheduleSave()
    }

    func setAlwaysOnTop(_ id: UUID, _ value: Bool) {
        mutate(id) { $0.alwaysOnTop = value }
        scheduleSave()
    }

    func setFontSize(_ id: UUID, _ size: Double) {
        mutate(id) { $0.fontSize = size }
        scheduleSave()
    }

    func updateFrame(_ id: UUID, x: Double, y: Double, width: Double, height: Double) {
        mutate(id) { note in
            note.x = x
            note.y = y
            note.width = width
            note.height = height
        }
        scheduleSave()
    }

    func delete(_ id: UUID) {
        notes = notes.filter { $0.id != id }
        saveNow()
    }
}
