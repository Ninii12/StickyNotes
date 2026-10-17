# StickyNotes

A native macOS sticky notes app built with Swift + SwiftUI/AppKit.

## Features
- Create, edit, and delete sticky notes
- Drag to move, resize from edges
- Color swatches
- Font size controls
- Pin / always-on-top toggle
- Auto-saves to `~/Library/Application Support/StickyNotes/notes.json`
- Restores all notes on launch

## Build

Requires Xcode / Swift 6 toolchain.

```sh
swift build -c release
cp .build/release/StickyNotes StickyNotes.app/Contents/MacOS/StickyNotes
open StickyNotes.app
```

## Run

```sh
open /Users/nancy/Projects/notes2/StickyNotes.app
```

## Controls
- `Cmd+N` — new note
- `+` button in a note — new note
- `x` button — delete note
- Drag the note's header (⠿ area) to move it
- Color dots — change color
- Pin icon — toggle always-on-top
- Text size icons — larger/smaller text
- Menu: File → Show All Notes (re-opens any note whose window was closed)
EOF
cd /Users/nancy/Projects/notes2 && ls