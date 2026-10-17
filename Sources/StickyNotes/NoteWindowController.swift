import AppKit
import SwiftUI
import Combine

/// Borderless panels refuse to become key by default, which makes typing impossible.
/// This subclass allows key/main status so the note can be edited and receive shortcuts.
final class StickyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class NoteWindowController: NSWindowController, NSWindowDelegate {
    let noteId: UUID
    let store: NoteStore
    var cancellables = Set<AnyCancellable>()

    init(note: Note, store: NoteStore, focusText: Bool) {
        self.noteId = note.id
        self.store = store

        let style: NSWindow.StyleMask = [.borderless, .resizable]
        let panel = StickyPanel(
            contentRect: NSRect(x: note.x, y: note.y, width: note.width, height: note.height),
            styleMask: style,
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.hasShadow = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = note.alwaysOnTop ? .floating : .normal
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.minSize = NSSize(width: 180, height: 120)
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .utilityWindow

        let view = NoteView(noteId: note.id, store: store, focusText: focusText) { [weak panel] event in
            panel?.performDrag(with: event)
        } onClose: {
            panel.close()
        }
        panel.contentView = NSHostingView(rootView: view)

        super.init(window: panel)
        panel.delegate = self

        store.$notes
            .receive(on: RunLoop.main)
            .sink { [weak self] notes in
                guard let self, let n = notes.first(where: { $0.id == self.noteId }) else { return }
                self.window?.level = n.alwaysOnTop ? .floating : .normal
            }
            .store(in: &cancellables)

        NotificationCenter.default.addObserver(self, selector: #selector(moved), name: NSWindow.didMoveNotification, object: panel)
        NotificationCenter.default.addObserver(self, selector: #selector(resized), name: NSWindow.didResizeNotification, object: panel)
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func moved(_ n: Notification) { persist() }
    @objc private func resized(_ n: Notification) { persist() }

    private func persist() {
        guard let w = window else { return }
        let f = w.frame
        store.updateFrame(noteId, x: Double(f.origin.x), y: Double(f.origin.y), width: Double(f.size.width), height: Double(f.size.height))
    }

    func windowWillClose(_ notification: Notification) {
        if let app = NSApp.delegate as? AppDelegate, app.isTerminating {
            app.controllers.removeValue(forKey: noteId)
            return
        }
        store.delete(noteId)
        (NSApp.delegate as? AppDelegate)?.controllers.removeValue(forKey: noteId)
    }
}
