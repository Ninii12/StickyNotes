import AppKit
import SwiftUI
import Combine

/// Borderless panels refuse to become key by default, which makes typing impossible.
/// This subclass allows key/main status so the note can be edited and receive shortcuts.
final class StickyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    /// Borderless panels have no close button, so `performClose:` (the Close Note
    /// menu item / Cmd+W) does nothing by default; route it through `close()`
    /// like the x button so it gets the delete + crumple animation too.
    override func performClose(_ sender: Any?) {
        close()
    }
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
        // Crumple-and-trash animation, played from a snapshot taken while the
        // window content is still alive.
        if let window, let snapshot = Self.snapshot(of: window) {
            NoteCloseAnimation.play(snapshot: snapshot, frame: window.frame, screen: window.screen)
        }
        store.delete(noteId)
        (NSApp.delegate as? AppDelegate)?.controllers.removeValue(forKey: noteId)
    }

    /// Renders the live window content into an image. Drawing our own view
    /// hierarchy needs no screen-recording permission.
    private static func snapshot(of window: NSWindow) -> NSImage? {
        guard let view = window.contentView, view.bounds.width > 1, view.bounds.height > 1 else { return nil }
        let size = view.bounds.size
        let scale = window.backingScaleFactor
        let pixelWidth = Int(size.width * scale)
        let pixelHeight = Int(size.height * scale)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(
                data: nil,
                width: pixelWidth,
                height: pixelHeight,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
              )
        else { return nil }

        // layer.render(in:) draws with an AppKit origin (bottom-left) while a
        // bitmap's first row is the top, so flip vertically to compensate.
        ctx.scaleBy(x: scale, y: scale)
        ctx.translateBy(x: 0, y: size.height)
        ctx.scaleBy(x: 1, y: -1)
        if let layer = view.layer {
            layer.render(in: ctx)
        } else {
            guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return nil }
            view.cacheDisplay(in: view.bounds, to: rep)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
            view.draw(view.bounds)
            NSGraphicsContext.restoreGraphicsState()
        }
        guard let cgImage = ctx.makeImage() else { return nil }
        return NSImage(cgImage: cgImage, size: size)
    }
}
