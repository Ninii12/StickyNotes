# StickyNotes

A native macOS sticky notes app built with Swift + SwiftUI/AppKit.

## Features
- Create, edit, and delete sticky notes
- Drag to move, resize from edges
- Color swatches (pastel palette; replaced by the photo when a background image is set)
- Font family and text color picker (the **Aa** button opens a popover)
- Optional background image per note
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

## Share without the App Store

Build a universal (Apple Silicon + Intel) bundle and package it:

```sh
swift build -c release --arch arm64 --arch x86_64
cp .build/out/Products/Release/StickyNotes /tmp/dist-stage/StickyNotes.app/Contents/MacOS/StickyNotes
codesign --force --sign - /tmp/dist-stage/StickyNotes.app
ditto -c -k --sequesterRsrc --keepParent /tmp/dist-stage/StickyNotes.app dist/StickyNotes.zip
```

The bundle is ad-hoc signed only, so recipients must clear the quarantine flag once:

```sh
xattr -dr com.apple.quarantine /Applications/StickyNotes.app
```

or use System Settings → Privacy & Security → "Open Anyway" after the first attempt.
Copying from a USB stick or network share skips quarantine entirely. For downloads that
open with no warning, sign with a Developer ID certificate and notarize (requires the
paid Apple Developer Program; no App Store submission or review involved).

## Controls
- `Cmd+N` — new note
- `+` button in a note — new note
- `x` button — delete note
- Drag the note's header (⠿ area) to move it
- Color dots — change color
- Photo icon — choose or replace the note's background image (copied into `~/Library/Application Support/StickyNotes/Images/`)
- ⊖ button (only shown when an image is set) — remove the background image
- Pin icon — toggle always-on-top
- Text size icons — larger/smaller text
- **Aa** icon — pick a font family and a text color
- Menu: File → Show All Notes (re-opens any note whose window was closed)
EOF
cd /Users/nancy/Projects/notes2 && ls