import SwiftUI

struct SettingsView: View {
    @Binding var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    @State private var defaultCwd: String = ""
    @State private var fontSize: String = ""
    @State private var fontColor: Color = .white
    @State private var defaultShell: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: "#c9a227") ?? .yellow)

            // Default Working Directory
            VStack(alignment: .leading, spacing: 4) {
                Text("Default Working Directory")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.secondary)
                HStack {
                    TextField("/Users/you/Code", text: $defaultCwd)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13, design: .monospaced))
                    Button("Browse...") {
                        let panel = NSOpenPanel()
                        panel.canChooseFiles = false
                        panel.canChooseDirectories = true
                        panel.allowsMultipleSelection = false
                        if panel.runModal() == .OK, let url = panel.url {
                            defaultCwd = url.path
                        }
                    }
                }
            }

            HStack(spacing: 16) {
                // Font Size
                VStack(alignment: .leading, spacing: 4) {
                    Text("Font Size")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                    TextField("14", text: $fontSize)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13, design: .monospaced))
                        .frame(width: 80)
                }

                // Font Color
                VStack(alignment: .leading, spacing: 4) {
                    Text("Font Color")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                    HStack {
                        ColorPicker("", selection: $fontColor, supportsOpacity: false)
                            .labelsHidden()
                        Button("Reset") {
                            fontColor = Color(red: 0.90, green: 0.93, blue: 0.95)
                        }
                        .font(.system(size: 11, design: .monospaced))
                    }
                }
            }

            // Default Shell
            VStack(alignment: .leading, spacing: 4) {
                Text("Default Shell (blank = system default)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.secondary)
                TextField("/bin/zsh", text: $defaultShell)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, design: .monospaced))
            }

            Divider()

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(Color(hex: "#c9a227") ?? .yellow)
            }

            Text("Cmd+1-9 switch tabs, Cmd+Shift+arrows cycle, Cmd+\\ split, Cmd+N new, Cmd+W close")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary.opacity(0.5))
        }
        .padding(24)
        .frame(width: 480)
        .onAppear {
            defaultCwd = settings.defaultCwd ?? ""
            fontSize = "\(settings.fontSize)"
            defaultShell = settings.defaultShell ?? ""
            if let hex = settings.fontColor {
                fontColor = Color(hex: hex) ?? Color(red: 0.90, green: 0.93, blue: 0.95)
            }
        }
    }

    private func save() {
        settings.defaultCwd = defaultCwd.isEmpty ? nil : defaultCwd
        settings.fontSize = Int(fontSize) ?? 14
        settings.defaultShell = defaultShell.isEmpty ? nil : defaultShell
        settings.fontColor = fontColor.toHex()
        try? settings.save()
        dismiss()
    }
}

// MARK: - Color to hex

extension Color {
    func toHex() -> String? {
        guard let components = NSColor(self).usingColorSpace(.sRGB) else { return nil }
        let r = Int(components.redComponent * 255)
        let g = Int(components.greenComponent * 255)
        let b = Int(components.blueComponent * 255)
        return String(format: "#%02x%02x%02x", r, g, b)
    }
}
