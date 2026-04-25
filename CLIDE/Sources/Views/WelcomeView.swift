import SwiftUI

struct WelcomeView: View {
    let tools: [ToolConfig]
    let hasSavedSession: Bool
    let onLaunchTool: (ToolConfig) -> Void
    let onNewTerminal: () -> Void
    let onRestoreSession: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            // ASCII Logo
            Text(asciiLogo)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Color(hex: "#c9a227") ?? .yellow)
                .shadow(color: Color(hex: "#c9a227")?.opacity(0.25) ?? .clear, radius: 20)
                .multilineTextAlignment(.center)

            Text("Command Line Integrated Development Environment")
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(.secondary)

            // Clyde mascot
            Text(clydeMascot)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary.opacity(0.5))
                .multilineTextAlignment(.center)

            // Session restore prompt
            if hasSavedSession {
                VStack(spacing: 10) {
                    Text("Previous session found")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.secondary)

                    HStack(spacing: 12) {
                        Button(action: onRestoreSession) {
                            Text("Restore Session")
                                .font(.system(size: 13, design: .monospaced))
                        }
                        .buttonStyle(CLIDEButtonStyle(highlight: true))

                        Button(action: {}) {
                            Text("New Session")
                                .font(.system(size: 13, design: .monospaced))
                        }
                        .buttonStyle(CLIDEButtonStyle())
                    }
                }
                .padding(16)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(hex: "#c9a227") ?? .yellow, lineWidth: 1)
                )
                .cornerRadius(8)
            }

            // Quick Launch
            VStack(spacing: 12) {
                Text("QUICK LAUNCH")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.secondary)
                    .tracking(2)

                HStack(spacing: 12) {
                    ForEach(tools) { tool in
                        Button(action: { onLaunchTool(tool) }) {
                            HStack(spacing: 8) {
                                Text(tool.shortcut)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1)
                                    .background(Color(nsColor: .controlBackgroundColor))
                                    .cornerRadius(3)
                                Text(tool.name)
                                    .font(.system(size: 13, design: .monospaced))
                            }
                        }
                        .buttonStyle(CLIDEButtonStyle())
                    }

                    Button(action: onNewTerminal) {
                        HStack(spacing: 8) {
                            Text("T")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(Color(nsColor: .controlBackgroundColor))
                                .cornerRadius(3)
                            Text("Terminal")
                                .font(.system(size: 13, design: .monospaced))
                        }
                    }
                    .buttonStyle(CLIDEButtonStyle())
                }

                HStack(spacing: 4) {
                    Text("[T]").foregroundColor(Color(hex: "#c9a227") ?? .yellow)
                    Text("New Terminal").foregroundColor(.secondary.opacity(0.5))
                    Text("[S]").foregroundColor(Color(hex: "#c9a227") ?? .yellow)
                    Text("Settings").foregroundColor(.secondary.opacity(0.5))
                    Text("[?]").foregroundColor(Color(hex: "#c9a227") ?? .yellow)
                    Text("Help").foregroundColor(.secondary.opacity(0.5))
                }
                .font(.system(size: 12, design: .monospaced))
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.051, green: 0.067, blue: 0.090))
    }

    private var asciiLogo: String {
        """
         ██████╗██╗     ██╗██████╗ ███████╗
        ██╔════╝██║     ██║██╔══██╗██╔════╝
        ██║     ██║     ██║██║  ██║█████╗
        ██║     ██║     ██║██║  ██║██╔══╝
        ╚██████╗███████╗██║██████╔╝███████╗
         ╚═════╝╚══════╝╚═╝╚═════╝ ╚══════╝
        """
    }

    private var clydeMascot: String {
        """
           ┌─────────┐
           │  ◉   ◉  │
           │    ▽    │
           │  ╰───╯  │
           └────┬────┘
                │
           ╔════╧════╗
           ║  CLYDE  ║
           ╚═════════╝
        """
    }
}

struct CLIDEButtonStyle: ButtonStyle {
    var highlight: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(configuration.isPressed
                ? Color(nsColor: .controlBackgroundColor).opacity(0.8)
                : Color(nsColor: .controlBackgroundColor).opacity(0.3))
            .foregroundColor(highlight ? Color(hex: "#c9a227") ?? .yellow : .primary)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(highlight
                        ? Color(hex: "#c9a227") ?? .yellow
                        : Color(nsColor: .separatorColor), lineWidth: 1)
            )
            .cornerRadius(6)
    }
}
