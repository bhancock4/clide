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

A native macOS terminal workspace for CLI-based AI development tools. CLIDE gives you a purpose-built terminal window manager with multi-column layouts, terminal pairing, broadcast typing, and a send-to system — designed for workflows that involve Claude Code, Gemini CLI, Aider, and other AI coding assistants side by side.

Built with Swift, SwiftTerm, and AppKit. No Electron, no web views, no xterm.js.

---

## Features

### Multi-Column Stacked Layout
- Unlimited columns, each with unlimited vertically stacked terminals
- Draggable dividers between all terminals and columns
- New splits take 1/3 of available space by default, compress gracefully
- Any column can spawn another column to its right

### Terminal Pairing
- Pair any terminal with any other(s) via drag-and-drop or right-click menu
- Colored stripe indicators show pairing group membership
- Auto-assigned unique colors per group (8-color palette)
- Send selected text to all paired terminals at once (Send & Run)
- Selection action bar with multi-target checkbox popover

### Broadcast Typing
- Click the antenna icon on terminal headers to add them to a broadcast group
- Type in one terminal, keystrokes go to all broadcast members simultaneously
- Great for running the same command across multiple environments
- Visual indicator: amber antenna icon lights up on broadcast-active terminals

### Saved Layouts
- Save your current terminal arrangement as a named layout
- Layouts preserve: columns, terminals per column, tool commands, pairings, window size
- Set a default layout that auto-loads on startup
- Switch layouts mid-session from View > Switch Layout
- Launch with a specific layout: `--layout "My Layout"`
- Visual layout editor for designing grid configurations

### Send-To System
- Select text in any terminal, a floating action bar appears
- Pick targets via checkbox popover — paired terminals checked by default
- Send (paste) or Run (paste + execute) to one or many terminals
- Right-click context menu with full send-to options
- Cmd+Return sends to all paired terminals

### Clyde the Mascot
- Animated golden C mascot on the welcome screen
- Blinks, chomps, and spits out rotating tips about app features
- 100 contextual tips covering shortcuts, workflows, and hidden features
- Pixel-block app icon matching the ASCII logo aesthetic

---

## Quick Start

### Prerequisites

- macOS 13+ (Ventura or later)
- Xcode Command Line Tools: `xcode-select --install`

### Build & Run

```bash
cd CLIDE
swift build
swift run
```

### Run with a specific layout

```bash
swift run CLIDE -- --layout "My Dev Layout"
```

### Skip saved session restore

```bash
swift run CLIDE -- --new
```

### Run tests

```bash
cd CLIDE
swift test
```

---

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
| `L` | Load default layout |
| `S` | Open settings |

### Workspace

| Shortcut | Action |
|----------|--------|
| `Cmd+\` | Toggle/add column |
| `Cmd+N` | New terminal in focused column |
| `Cmd+Shift+N` | New terminal in next column |
| `Cmd+W` | Close active terminal |
| `Cmd+Shift+[` | Previous terminal (cycle focus) |
| `Cmd+Shift+]` | Next terminal (cycle focus) |
| `Cmd+Return` | Send selection to paired terminals |
| `Cmd+Shift+Return` | Send selection & run in paired terminals |
| `Cmd+,` | Settings |

### Terminal Headers

| Action | Effect |
|--------|--------|
| Click header | Focus that terminal |
| Double-click header | Rename terminal |
| Click antenna icon | Toggle broadcast membership |
| Drag header → another header | Create pairing |
| Right-click header | Pair/unpair menu + broadcast toggle |

---

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
  "defaultShell": null,
  "promptForDirectory": false,
  "layouts": []
}
```

Edit via the Settings panel (`Cmd+,`), the layout editor, or directly in the JSON file.

### Adding Custom Tools

Add entries to the `tools` array with any CLI command. Each tool needs:
- `name` — display name
- `command` — executable to run
- `args` — array of arguments (shell-escaped automatically)
- `shortcut` — single letter for welcome screen quick-launch
- `color` — hex color for the terminal dot indicator

---

## Architecture

Native macOS app built with Swift and AppKit:

```
CLIDE/
├── Sources/
│   ├── CLIDEApp.swift                  # Entry point, menus, layout switching
│   ├── Models/
│   │   ├── AppSettings.swift           # Settings with atomic JSON persistence
│   │   ├── SavedSession.swift          # Session save/restore (backward-compat)
│   │   ├── TerminalLayout.swift        # Layout model (columns, terminals, pairings)
│   │   └── ToolConfig.swift            # CLI tool definitions
│   ├── Terminal/
│   │   ├── TerminalSession.swift       # SwiftTerm wrapper, PTY, shell escaping
│   │   └── SessionManager.swift        # Multi-column sessions, pairing, layout capture
│   └── AppKit/
│       ├── MainWindowController.swift  # Dynamic columns, broadcast, selection bar
│       ├── WelcomeViewController.swift # Welcome screen, Clyde animation, tips
│       ├── TerminalTabBar.swift        # Cell headers, pairing stripes, drag-to-pair
│       ├── LayoutEditorViewController.swift  # Visual grid layout editor
│       ├── SettingsPanel.swift         # Settings sheet with layout management
│       ├── SendToMenu.swift            # Right-click send-to context menu
│       ├── NewSessionDialog.swift      # Working directory prompt
│       ├── AppIcon.swift               # Programmatic pixel-block icon
│       └── Theme.swift                 # Color palette and typography
├── Tests/
│   └── SettingsTests.swift             # 46 tests across 9 suites
└── Package.swift
```

### Key Design Decisions

- **Pure AppKit, no SwiftUI** — SwiftUI's responder chain intercepts keyboard events before they reach NSView-based terminal views. AppKit gives full control over first responder management.
- **SwiftTerm for terminal rendering** — handles PTY spawning, ANSI parsing, cursor positioning, scrollback, and resize natively. No web layer.
- **Login shell for tool launch** — tools are launched by starting a login shell first, then sending the command after shell init. This ensures the user's full PATH is available (homebrew, nvm, cargo, etc.).
- **Shell-escaped arguments** — tool args are single-quote escaped to prevent injection from args with spaces or special characters.
- **Atomic file writes** — settings and session files are written to temp files first, then atomically swapped via `FileManager.replaceItemAt` to prevent corruption on crash.
- **O(1) session lookups** — session index dictionary for fast lookups in hot paths (keystroke and mouse event handlers).
- **Programmatic app icon** — generated via Core Graphics at launch so the app works as a bare `swift run` executable without a .app bundle.
- **Validated paths** — shell executable and working directory paths are validated before use, with safe fallbacks to `/bin/zsh` and home directory.

### Testing

46 tests across 9 suites covering:

| Suite | Coverage |
|-------|----------|
| AppSettings | Defaults, save/load roundtrip, layouts |
| SavedSession | Column format, backward compat (old panel format) |
| ToolConfig | Unique shortcuts, valid colors, unique IDs |
| TerminalLayout | Encode/decode, window frames, position hashing |
| Color Parsing | Hex parsing with/without #, invalid input, RGB values |
| SessionManager | Create, close, columns, tab cycling, label generation |
| Pairing | Create, dedupe, remove, unpair, paired sessions, cleanup |
| Layout Capture | Capture from sessions, capture with pairings |
| Clyde Tips | Count (100), no empties, no duplicates |

---

## Data Storage

| File | Location | Purpose |
|------|----------|---------|
| `settings.json` | `~/Library/Application Support/com.clide.app/` | Tools, appearance, layouts |
| `session.json` | `~/Library/Application Support/com.clide.app/` | Auto-saved session state |
| Window frame | UserDefaults (`CLIDEMainWindow`) | Window position/size |

---

## Roadmap

- [x] Native terminal rendering (SwiftTerm)
- [x] Quick-launch for CLI AI tools
- [x] Multi-column stacked terminal layout
- [x] Terminal pairing with colored indicators
- [x] Broadcast typing across terminals
- [x] Selection action bar with multi-target send
- [x] Saved/loadable named layouts with editor
- [x] Clyde mascot with animated tips
- [x] Session save/restore
- [x] Settings panel with layout management
- [x] Shell argument escaping and path validation
- [x] Atomic file persistence
- [x] 46-test suite
- [x] .app bundle packaging and DMG distribution
- [x] Homebrew cask
- [ ] Integrated diff viewer
- [ ] Cost/token tracking dashboard
- [ ] Conversation bookmarks

## License

MIT
