import SwiftUI
import AppKit

struct NoteView: View {
    let noteId: UUID
    @ObservedObject var store: NoteStore
    var focusText: Bool = false
    let onDrag: (NSEvent) -> Void
    let onClose: () -> Void

    @State private var isDragging = false
    @FocusState private var textFocused: Bool

    private var note: Note? { store.notes.first(where: { $0.id == noteId }) }

    var body: some View {
        VStack(spacing: 0) {
            header
            TextEditor(text: textBinding)
                .font(.system(size: note?.fontSize ?? 14))
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .focused($textFocused)
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
        }
        .background(Color(hex: note?.colorHex ?? "#FFF59D"))
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
        HStack(spacing: 6) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.black.opacity(0.35))

            ForEach(Note.defaultColors, id: \.self) { hex in
                Button {
                    store.setColor(noteId, hex)
                } label: {
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 13, height: 13)
                        .overlay(
                            Circle().stroke(Color.black.opacity(0.25), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .help("Change color")
            }

            Spacer()

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
        .padding(.horizontal, 10)
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

    private var textBinding: Binding<String> {
        Binding(
            get: { note?.text ?? "" },
            set: { store.updateText(noteId, $0) }
        )
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
            (r, g, b) = (255, 245, 157)
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
