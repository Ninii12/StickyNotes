import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct NoteView: View {
    let noteId: UUID
    @ObservedObject var store: NoteStore
    var focusText: Bool = false
    let onDrag: (NSEvent) -> Void
    let onClose: () -> Void

    @State private var isDragging = false
    @State private var showStylePopover = false
    @FocusState private var textFocused: Bool

    private var note: Note? { store.notes.first(where: { $0.id == noteId }) }

    private var editorFont: Font {
        let size = CGFloat(note?.fontSize ?? 14)
        let name = note?.resolvedFontName ?? Note.systemFontName
        return name == Note.systemFontName ? .system(size: size) : .custom(name, size: size)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            TextEditor(text: textBinding)
                .font(editorFont)
                .foregroundColor(Color(hex: note?.resolvedTextColor ?? Note.defaultTextColors[0]))
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .focused($textFocused)
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
        }
        .background {
            ZStack {
                if let name = note?.backgroundImage, let image = store.image(named: name) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Color(hex: note?.colorHex ?? Note.defaultColors[0])
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
        .onAppear {
            if focusText {
                DispatchQueue.main.async {
                    textFocused = true
                }
            }
        }
    }

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            headerContent(colors: Note.defaultColors)
            headerContent(colors: Array(Note.defaultColors.prefix(3)))
            headerContent(colors: Array(Note.defaultColors.prefix(2)))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.05))
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !isDragging else { return }
                    isDragging = true
                    if let event = NSApp.currentEvent {
                        onDrag(event)
                    }
                    DispatchQueue.main.async {
                        isDragging = false
                    }
                }
        )
    }

    /// Header contents. `ViewThatFits` falls back to fewer color swatches on narrow notes,
    /// e.g. when the extra background-image controls are shown.
    private func headerContent(colors: [String]) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.black.opacity(0.35))

            ForEach(colors, id: \.self) { hex in
                Button {
                    store.setColor(noteId, hex)
                } label: {
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle().stroke(Color.black.opacity(0.25), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .help("Change color")
            }

            Spacer()

            Button {
                showStylePopover = true
            } label: {
                Image(systemName: "textformat")
            }
            .buttonStyle(.plain)
            .help("Font & text color")
            .popover(isPresented: $showStylePopover, arrowEdge: .bottom) {
                stylePopover
            }

            Button {
                if let n = note {
                    store.setFontSize(noteId, max(10, n.fontSize - 1))
                }
            } label: {
                Image(systemName: "textformat.size.smaller")
            }
            .buttonStyle(.plain)
            .help("Smaller text")

            Button {
                if let n = note {
                    store.setFontSize(noteId, min(28, n.fontSize + 1))
                }
            } label: {
                Image(systemName: "textformat.size.larger")
            }
            .buttonStyle(.plain)
            .help("Larger text")

            Button {
                chooseBackgroundImage()
            } label: {
                Image(systemName: note?.backgroundImage == nil ? "photo" : "photo.fill")
            }
            .buttonStyle(.plain)
            .help("Background image")

            if note?.backgroundImage != nil {
                Button {
                    store.setBackgroundImage(noteId, nil)
                } label: {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.plain)
                .help("Remove background image")
            }

            Button {
                if let n = note {
                    store.setAlwaysOnTop(noteId, !n.alwaysOnTop)
                }
            } label: {
                Image(systemName: (note?.alwaysOnTop ?? true) ? "pin.fill" : "pin")
            }
            .buttonStyle(.plain)
            .help("Always on top")

            Button {
                (NSApp.delegate as? AppDelegate)?.createNewNote()
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.plain)
            .help("New note")

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
            .help("Delete note")
        }
    }

    private var textBinding: Binding<String> {
        Binding(
            get: { note?.text ?? "" },
            set: { store.updateText(noteId, $0) }
        )
    }

    /// Font family list plus text color swatches. The header is already packed, so
    /// these live in a popover behind the "Aa" button.
    private var stylePopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Font")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)

            ScrollView {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(Note.fontChoices, id: \.self) { name in
                        Button {
                            store.setFontName(noteId, name)
                        } label: {
                            HStack(spacing: 6) {
                                Text(fontDisplayName(name))
                                    .font(name == Note.systemFontName ? .system(size: 13) : .custom(name, size: 13))
                                Spacer()
                                if note?.resolvedFontName == name {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                }
                            }
                            .padding(.vertical, 3)
                            .padding(.horizontal, 6)
                            .contentShape(Rectangle())
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(Color.primary.opacity(note?.resolvedFontName == name ? 0.1 : 0))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(height: 190)

            Divider()

            Text("Text Color")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)

            HStack(spacing: 6) {
                ForEach(Note.defaultTextColors, id: \.self) { hex in
                    Button {
                        store.setTextColor(noteId, hex)
                    } label: {
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 16, height: 16)
                            .overlay(
                                Circle().stroke(
                                    (note?.resolvedTextColor ?? Note.defaultTextColors[0]) == hex
                                        ? Color.accentColor : Color.black.opacity(0.25),
                                    lineWidth: (note?.resolvedTextColor ?? Note.defaultTextColors[0]) == hex ? 2 : 1
                                )
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Text color")
                }
            }
        }
        .padding(12)
        .frame(width: 210)
    }

    private func fontDisplayName(_ name: String) -> String {
        name == Note.systemFontName ? "System" : name
    }

    /// Opens a file picker and copies the chosen image into the app's support directory.
    private func chooseBackgroundImage() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]
        panel.prompt = "Use Image"
        panel.message = "Choose a background image for this note"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if let name = store.importImage(from: url) {
            store.setBackgroundImage(noteId, name)
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (255, 249, 196)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}
