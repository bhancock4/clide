# CLIDE

**Command Line Integrated Development Environment**

```
 ██████╗██╗     ██╗██████╗ ███████╗
██╔════╝██║     ██║██╔══██╗██╔════╝
██║     ██║     ██║██║  ██║█████╗
██║     ██║     ██║██║  ██║██╔══╝
╚██████╗███████╗██║██████╔╝███████╗
 ╚═════╝╚══════╝╚═╝╚═════╝ ╚══════╝
```

A native macOS desktop workspace for CLI-based AI development tools. CLIDE gives you a purpose-built terminal window manager designed around the workflow of using Claude Code, Gemini CLI, Aider, Copilot CLI, Cursor, and other AI coding assistants.

Built with Swift, SwiftTerm, and AppKit for pixel-perfect terminal rendering.

## Why CLIDE?

CLI AI tools are becoming primary development environments, but they're stuck in generic terminals. CLIDE gives you:

- **Quick-launch** your favorite CLI dev tools with one keypress
- **Split-pane layout** — main AI terminal on the left, tabbed terminals on the right
- **Bidirectional paste** — select text in any terminal, right-click to paste it into another
- **Session persistence** — save and restore your workspace across restarts
- **Native terminal rendering** — SwiftTerm handles PTY, ANSI, scrollback, and resizing correctly (no xterm.js hacks)
- **Dark, terminal-native UI** with Clyde the robot mascot

## Quick Start

### Prerequisites

- macOS 13+ (Ventura or later)
- Xcode Command Line Tools: `xcode-select --install`

### Run

```bash
cd CLIDE
swift run
```

### Run with a fresh session (skip restore prompt)

```bash
swift run CLIDE -- --new
```

### Run tests

```bash
cd CLIDE
swift test
```

## Keyboard Shortcuts

### Welcome Screen

| Key | Action |
|-----|--------|
| `C` | Launch Claude Code |
| `G` | Launch Gemini CLI |
| `A` | Launch Aider |
| `O` | Launch Copilot CLI |
| `U` | Launch Cursor CLI |
| `T` | New plain terminal |
| `S` | Open settings |

### Workspace

| Shortcut | Action |
|----------|--------|
| `Cmd+\` | Toggle split view |
| `Cmd+N` | New terminal (main pane) |
| `Cmd+Shift+N` | New terminal (split pane) |
| `Cmd+W` | Close active terminal |
| `Cmd+Shift+Left/Right` | Cycle split pane tabs |
| `Cmd+,` | Settings |

## Architecture

Native macOS app built with Swift and AppKit:

```
CLIDE/
├── Sources/
│   ├── CLIDEApp.swift              # Entry point, NSApplication lifecycle, menus
│   ├── Models/
│   │   ├── AppSettings.swift       # Settings model with JSON persistence
│   │   ├── SavedSession.swift      # Session save/restore model
│   │   └── ToolConfig.swift        # CLI tool definitions
│   ├── Terminal/
│   │   ├── TerminalSession.swift   # SwiftTerm wrapper, PTY lifecycle, process delegate
│   │   └── SessionManager.swift    # Multi-session management, tab state
│   └── AppKit/
│       ├── MainWindowController.swift  # Window layout, split view, terminal attachment
│       ├── WelcomeViewController.swift # Welcome screen with branding and tool buttons
│       ├── TerminalTabBar.swift     # Tab bar with colored dots, close buttons, rename
│       ├── SettingsPanel.swift      # Settings sheet with folder picker, color well
│       ├── NewSessionDialog.swift   # Working directory prompt on new session
│       ├── SendToMenu.swift         # Right-click context menu for cross-terminal paste
│       ├── AppIcon.swift            # Programmatic Clyde icon for dock
│       └── Theme.swift              # Color and font constants
├── Tests/
│   └── SettingsTests.swift          # Settings, session, and tool config tests
└── Package.swift                    # Swift Package Manager manifest
```

### Key Design Decisions

- **Pure AppKit, no SwiftUI** — SwiftUI's responder chain intercepts keyboard events before they reach NSView-based terminal views. AppKit gives full control over first responder management.
- **SwiftTerm for terminal rendering** — handles PTY spawning, ANSI parsing, cursor positioning, scrollback, and resize natively. No web layer means no dimension mismatches.
- **Login shell for tool launch** — tools like `claude` and `gemini` are launched by starting a login shell first, then sending the command. This ensures the user's full PATH is available.
- **Programmatic app icon** — generated via Core Graphics at launch so the app works as a bare `swift run` executable without a .app bundle.

## Configuration

Settings are stored at `~/Library/Application Support/com.clide.app/settings.json`:

```json
{
  "tools": [
    { "name": "Claude Code", "command": "claude", "args": [], "shortcut": "C", "color": "#d97706" },
    { "name": "Gemini CLI", "command": "gemini", "args": [], "shortcut": "G", "color": "#2563eb" },
    { "name": "Aider", "command": "aider", "args": [], "shortcut": "A", "color": "#16a34a" },
    { "name": "Copilot CLI", "command": "gh", "args": ["copilot"], "shortcut": "O", "color": "#6e40c9" },
    { "name": "Cursor CLI", "command": "cursor", "args": [], "shortcut": "U", "color": "#00b4d8" }
  ],
  "fontSize": 14,
  "fontColor": "#e6edf3",
  "defaultCwd": "/Users/you/Code",
  "promptForDirectory": false
}
```

Edit via the Settings panel (`Cmd+,`) or directly in the JSON file.

## Roadmap

- [x] Native terminal rendering (SwiftTerm)
- [x] Quick-launch for CLI AI tools
- [x] Split-pane layout with tabbed terminals
- [x] Bidirectional paste between terminals
- [x] Session save/restore with startup prompt
- [x] Settings panel with folder picker and color picker
- [x] New session directory prompt
- [x] Clyde app icon
- [ ] File tree sidebar
- [ ] Integrated diff viewer
- [ ] Cost/token tracking dashboard
- [ ] Conversation bookmarks
- [ ] Prompt snippets library
- [ ] Rules/config library per tool

## License

MIT
