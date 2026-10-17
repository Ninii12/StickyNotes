import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = NoteStore()
    var controllers: [UUID: NoteWindowController] = [:]
    var isTerminating = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        store.load()

        if store.notes.isEmpty {
            createNewNote()
        } else {
            for note in store.notes {
                openWindow(for: note)
            }
        }

        setupMenu()
        activateApp()

        if CommandLine.arguments.contains("--dump-windows") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                print("DIAG appActive=\(NSApp.isActive) keyWindow=\(String(describing: NSApp.keyWindow.map { type(of: $0) }))")
                for w in NSApp.windows {
                    print("DIAG window class=\(type(of: w)) title=\(w.title.isEmpty ? "(none)" : w.title) frame=\(w.frame) level=\(w.level.rawValue) visible=\(w.isVisible) key=\(w.isKeyWindow) canBecomeKey=\(w.canBecomeKey)")
                }
                NSApp.terminate(nil)
            }
        }
    }

    func createNewNote() {
        let note = store.addNote()
        openWindow(for: note, focusText: true)
    }

    @discardableResult
    func openWindow(for note: Note, focusText: Bool = false) -> NoteWindowController {
        let controller = NoteWindowController(note: note, store: store, focusText: focusText)
        controllers[note.id] = controller
        controller.showWindow(nil)
        controller.window?.orderFrontRegardless()
        controller.window?.makeKey()
        return controller
    }

    func showAllNotes() {
        for note in store.notes where controllers[note.id] == nil {
            openWindow(for: note)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        isTerminating = true
        store.saveNow()
        return .terminateNow
    }

    func applicationWillTerminate(_ notification: Notification) {
        isTerminating = true
        store.saveNow()
    }

    private func activateApp() {
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func setupMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(withTitle: "About StickyNotes", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit StickyNotes", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let fileMenuItem = NSMenuItem()
        mainMenu.addItem(fileMenuItem)
        let fileMenu = NSMenu(title: "File")
        fileMenuItem.submenu = fileMenu

        let newItem = NSMenuItem(title: "New Note", action: #selector(newNoteAction), keyEquivalent: "n")
        newItem.target = self
        fileMenu.addItem(newItem)

        let showAllItem = NSMenuItem(title: "Show All Notes", action: #selector(showAllNotesAction), keyEquivalent: "")
        showAllItem.target = self
        fileMenu.addItem(showAllItem)

        fileMenu.addItem(NSMenuItem.separator())
        let closeItem = NSMenuItem(title: "Close Note", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileMenu.addItem(closeItem)

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        NSApp.mainMenu = mainMenu
    }

    @objc private func newNoteAction() {
        createNewNote()
    }

    @objc private func showAllNotesAction() {
        showAllNotes()
    }
}

@main
enum StickyNotesMain {
    @MainActor private static var delegate: AppDelegate?

    @MainActor
    static func main() {
        let delegate = AppDelegate()
        StickyNotesMain.delegate = delegate

        let app = NSApplication.shared
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }
}
