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

A purpose-built desktop workspace for CLI-based AI development tools. CLIDE provides an opinionated terminal window manager designed around the workflow of using Claude Code, Gemini CLI, Aider, and other AI coding assistants.

## Why CLIDE?

CLI AI tools are becoming primary development environments, but they're stuck in generic terminals. CLIDE gives you:

- **Quick-launch** for your favorite CLI dev tools with one keypress
- **Two-pane terminal layout** — main AI terminal + collapsible secondary panel with multiple tabs
- **Bidirectional send-to-terminal** — highlight text in one terminal, send it to another
- **File tree sidebar** for quick navigation
- **Session management** — save and restore your workspace
- **Dark, terminal-native UI** that feels right at home

## Quick Start

### Prerequisites

- [Rust](https://rustup.rs/) (1.70+)
- [Node.js](https://nodejs.org/) (18+)
- npm

### Development

```bash
# Install dependencies
npm install

# Run in development mode (hot-reload)
npm run tauri dev

# Run tests
npm run test:ci                    # Frontend tests
cd src-tauri && cargo test         # Backend tests

# Build for production
npm run tauri build
```

### Keyboard Shortcuts (Welcome Screen)

| Key | Action |
|-----|--------|
| `C` | Launch Claude Code |
| `G` | Launch Gemini CLI |
| `A` | Launch Aider |
| `T` | New plain terminal |
| `S` | Settings |
| `?` | Help |

## Architecture

CLIDE is built with [Tauri v2](https://v2.tauri.app/), combining a Rust backend with a web frontend:

```
clide/
├── src-tauri/          # Rust backend
│   └── src/
│       ├── lib.rs      # Tauri app setup and command handlers
│       ├── main.rs     # Entry point
│       ├── pty.rs      # PTY session manager (terminal spawning, I/O, resize)
│       └── settings.rs # Settings persistence (JSON)
├── src/                # TypeScript frontend
│   ├── main.ts         # App initialization, UI wiring, keyboard shortcuts
│   ├── terminal-manager.ts  # xterm.js terminal lifecycle management
│   ├── branding.ts     # ASCII art, mascot, version
│   └── styles.css      # Dark terminal-native theme
└── index.html          # App shell
```

### Backend (Rust)

- **PTY Manager** (`pty.rs`): Spawns and manages pseudo-terminal sessions using `portable-pty`. Each terminal gets its own PTY with a reader thread that emits data events to the frontend via Tauri's event system.
- **Settings** (`settings.rs`): Persists user configuration (tool definitions, theme, font settings) as JSON in the app's config directory.
- **Commands** (`lib.rs`): Tauri commands for spawning, writing to, resizing, and closing terminals, plus settings CRUD.

### Frontend (TypeScript)

- **Terminal Manager** (`terminal-manager.ts`): Manages xterm.js terminal instances, handles PTY I/O bridging, tab state, and panel assignments.
- **Main** (`main.ts`): Orchestrates the UI — welcome screen, workspace layout, tab rendering, keyboard shortcuts, and panel resizing.

### Data Flow

```
User keypress → xterm.js → Tauri command (write_terminal) → PTY stdin
PTY stdout → Reader thread → Tauri event (pty-data-{id}) → xterm.js → Screen
```

## Configuration

Settings are stored in your platform's app config directory:

- **macOS**: `~/Library/Application Support/com.clide.app/settings.json`
- **Linux**: `~/.config/com.clide.app/settings.json`
- **Windows**: `%APPDATA%/com.clide.app/settings.json`

### Default Tool Configuration

```json
{
  "tools": [
    { "name": "Claude Code", "command": "claude", "args": [], "shortcut": "C", "color": "#d97706" },
    { "name": "Gemini CLI", "command": "gemini", "args": [], "shortcut": "G", "color": "#2563eb" },
    { "name": "Aider", "command": "aider", "args": [], "shortcut": "A", "color": "#16a34a" }
  ],
  "theme": "dark",
  "font_size": 14,
  "font_family": "Menlo, Monaco, 'Courier New', monospace"
}
```

## Testing

Both backend and frontend have unit tests:

```bash
# Rust tests (PTY manager, settings persistence)
cd src-tauri && cargo test

# TypeScript tests (branding, UI logic)
npm run test:ci

# Watch mode for frontend tests
npm run test
```

Tests run automatically before production builds via `npm run build`.

## Building for Distribution

```bash
# Build for current platform
npm run tauri build
```

This produces platform-specific installers:
- **macOS**: `.dmg` in `src-tauri/target/release/bundle/dmg/`
- **Windows**: `.msi` in `src-tauri/target/release/bundle/msi/`
- **Linux**: `.AppImage` and `.deb` in `src-tauri/target/release/bundle/`

## Roadmap

- [ ] Bidirectional send-to-terminal (highlight and send)
- [ ] Integrated diff viewer with green/red highlighting
- [ ] File tree sidebar with file explorer
- [ ] Session save/restore
- [ ] Cost/token tracking dashboard
- [ ] Conversation bookmarks
- [ ] Prompt snippets library
- [ ] Rules/config library per tool
- [ ] Click-to-edit file viewer

## License

MIT
