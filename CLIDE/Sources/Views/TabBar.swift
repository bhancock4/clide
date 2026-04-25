import SwiftUI

struct TabBar: View {
    let sessions: [TerminalSession]
    let activeId: UUID?
    let onSelect: (UUID) -> Void
    let onClose: (UUID) -> Void
    let onRename: (UUID) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                    TabItem(
                        session: session,
                        index: index,
                        isActive: session.id == activeId,
                        onSelect: { onSelect(session.id) },
                        onClose: { onClose(session.id) },
                        onRename: { onRename(session.id) }
                    )
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

struct TabItem: View {
    @ObservedObject var session: TerminalSession
    let index: Int
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    let onRename: () -> Void

    @State private var isHovering = false
    @State private var isEditing = false
    @State private var editText = ""

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color(hex: colorForCommand(session.command)) ?? .gray)
                .frame(width: 8, height: 8)

            if isEditing {
                TextField("", text: $editText, onCommit: {
                    if !editText.trimmingCharacters(in: .whitespaces).isEmpty {
                        session.label = editText
                    }
                    isEditing = false
                })
                .textFieldStyle(.plain)
                .font(.system(size: 12, design: .monospaced))
                .frame(width: 100)
                .onExitCommand { isEditing = false }
            } else {
                Text(session.label)
                    .font(.system(size: 12, design: .monospaced))
                    .lineLimit(1)
            }

            if index < 9 {
                Text("\(index + 1)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.5))
            }

            if isHovering {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(isActive ? Color(nsColor: .controlBackgroundColor) : Color.clear)
        .cornerRadius(4)
        .onHover { isHovering = $0 }
        .onTapGesture { onSelect() }
        .onTapGesture(count: 2) {
            editText = session.label
            isEditing = true
        }
        .contextMenu {
            Button("Rename...") {
                editText = session.label
                isEditing = true
            }
            Button(session.panel == .main ? "Move to Split" : "Move to Main") {
                onRename()
            }
            Divider()
            Button("Close", role: .destructive) { onClose() }
        }
    }

    private func colorForCommand(_ cmd: String) -> String {
        let defaults: [String: String] = [
            "claude": "#d97706",
            "gemini": "#2563eb",
            "aider": "#16a34a",
            "gh": "#6e40c9",
            "cursor": "#00b4d8",
        ]
        return defaults[cmd] ?? "#8b949e"
    }
}

// MARK: - Color from hex

extension Color {
    init?(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 6, let val = UInt64(h, radix: 16) else { return nil }
        let r = Double((val >> 16) & 0xFF) / 255.0
        let g = Double((val >> 8) & 0xFF) / 255.0
        let b = Double(val & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
