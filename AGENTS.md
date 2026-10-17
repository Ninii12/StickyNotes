# StickyNotes — agent instructions

Native macOS sticky notes app: Swift 6 package (SPM), SwiftUI views hosted inside AppKit `NSPanel`s. One floating window per note.

## Build, run, verify

```sh
swift build -c release
cp .build/release/StickyNotes StickyNotes.app/Contents/MacOS/StickyNotes
open StickyNotes.app
```

- Always rebuild **and** re-copy the binary into `StickyNotes.app` before testing; the bundle does not update itself.
- User data lives at `~/Library/Application Support/StickyNotes/notes.json` (JSON array of notes). Deleting it resets to a fresh note on next launch.
- Diagnostics: `open StickyNotes.app --stdout /tmp/diag.txt --args --dump-windows` prints all windows (class, frame, level, key status) and exits after 2s.
- Screen capture and System Events/accessibility (osascript) are NOT permitted on this machine. Verify visually via window metadata instead:
  - List on-screen windows with `CGWindowListCopyWindowInfo` in a small `swift` script; expect one `StickyPanel` window per note at level 3 (`floating`).
  - For typing/interaction, add a temporary in-app test that finds the `NSTextView` descendant of the hosting view, makes it first responder, and sends synthetic `NSEvent.keyEvent`s through `panel.sendEvent`. Remove test code before committing.

## Architecture

- `StickyNotesApp.swift` — `@main enum StickyNotesMain` uses a pure AppKit lifecycle. Do **not** reintroduce the SwiftUI `App`/`Settings`/`WindowGroup` scenes: the `Settings` scene caused a phantom blank 900×450 window at launch. Menu bar is built manually; `applicationShouldTerminate`/`applicationWillTerminate` set `isTerminating` so quitting does not delete notes.
- `NoteWindowController.swift` — must use `StickyPanel` (subclass overriding `canBecomeKey`/`canBecomeMain`); a plain borderless `NSPanel` cannot become key, so typing silently fails. Keep `hidesOnDeactivate = false` (notes must stay visible when the app loses focus) and `isMovableByWindowBackground = true`.
- `NoteStore.swift` — `@Published notes`. Mutating an array element in place does not publish; always reassign the whole array (see the `mutate(_:_:)` helper). Saves are debounced ~0.4s; `saveNow()` runs on terminate/close.
- `NoteView.swift` — header drag calls `panel.performDrag(with:)` with `NSApp.currentEvent` (this is what actually moves the window). `focusText` auto-focuses the editor for newly created notes only.
- `Note.swift` — Codable model; keep new fields optional or provide defaults so existing `notes.json` files still decode. Persist window frames in AppKit coordinates (bottom-left origin).

## Conventions

- Swift 6 strict concurrency: annotate AppKit/UI classes (`AppDelegate`, `NoteWindowController`, `NoteStore`) with `@MainActor`; hop to the main actor in timer/async callbacks.
- Closing a note window deletes the note (classic Stickies behavior). `Cmd+N` creates a note; `File → Show All Notes` reopens notes whose windows were closed without deleting.
- Deployment target is macOS 13; guard newer APIs with `if #available`.
- Commit source only: `.build/` and `StickyNotes.app/` are gitignored. Do not commit the built binary or `notes.json`.
