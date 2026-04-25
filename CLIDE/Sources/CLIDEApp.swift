import SwiftUI

@main
struct CLIDEApp: App {
    @StateObject private var manager: SessionManager
    @State private var showWelcome = true
    @State private var splitVisible = false
    @State private var showSettings = false
    @State private var settings: AppSettings
    @State private var hasSavedSession: Bool

    private let forceNew: Bool

    init() {
        let s = AppSettings.load()
        _settings = State(initialValue: s)
        _manager = StateObject(wrappedValue: SessionManager(settings: s))

        let forceNew = CommandLine.arguments.contains("--new")
        self.forceNew = forceNew

        let saved = SavedSession.load()
        _hasSavedSession = State(initialValue: !forceNew && saved.hasSavedTerminals)
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if showWelcome {
                    WelcomeView(
                        tools: settings.tools,
                        hasSavedSession: hasSavedSession,
                        onLaunchTool: { tool in
                            launchTool(tool)
                        },
                        onNewTerminal: {
                            manager.createSession(label: "Terminal", panel: .main)
                            showWelcome = false
                        },
                        onRestoreSession: {
                            manager.restoreSession()
                            splitVisible = !manager.secondarySessions.isEmpty
                            showWelcome = false
                            hasSavedSession = false
                        },
                        onOpenSettings: {
                            showSettings = true
                        }
                    )
                    .onAppear {
                        setupKeyboardShortcuts()
                    }
                } else {
                    WorkspaceView(
                        manager: manager,
                        splitVisible: $splitVisible,
                        onHome: {
                            manager.saveSession()
                            showWelcome = true
                        },
                        onOpenSettings: {
                            showSettings = true
                        }
                    )
                }
            }
            .frame(minWidth: 800, minHeight: 500)
            .sheet(isPresented: $showSettings) {
                SettingsView(settings: $settings)
            }
            .onDisappear {
                manager.saveSession()
            }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1280, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Terminal") {
                    manager.createSession(label: "Terminal", panel: .main)
                    showWelcome = false
                }
                .keyboardShortcut("n")

                Button("New Split Terminal") {
                    splitVisible = true
                    manager.createSession(label: "Terminal", panel: .secondary)
                    showWelcome = false
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }

            CommandGroup(after: .toolbar) {
                Button("Toggle Split View") {
                    toggleSplit()
                }
                .keyboardShortcut("\\")

                Divider()

                // Tab switching
                ForEach(1...9, id: \.self) { num in
                    Button("Tab \(num)") {
                        manager.selectTab(index: num - 1, panel: .main)
                    }
                    .keyboardShortcut(KeyEquivalent(Character("\(num)")))
                }

                Divider()

                Button("Previous Tab") {
                    manager.cycleTab(panel: .main, forward: false)
                }
                .keyboardShortcut(.leftArrow, modifiers: [.command, .shift])

                Button("Next Tab") {
                    manager.cycleTab(panel: .main, forward: true)
                }
                .keyboardShortcut(.rightArrow, modifiers: [.command, .shift])
            }

            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    showSettings = true
                }
                .keyboardShortcut(",")
            }
        }
    }

    private func launchTool(_ tool: ToolConfig) {
        manager.createSession(
            label: tool.name,
            command: tool.command,
            args: tool.args,
            panel: .main
        )
        showWelcome = false
    }

    private func toggleSplit() {
        if splitVisible {
            splitVisible = false
        } else {
            splitVisible = true
            if manager.secondarySessions.isEmpty {
                manager.createSession(label: "Terminal", panel: .secondary)
            }
        }
    }

    private func setupKeyboardShortcuts() {
        // Welcome screen key handlers are handled by SwiftUI .commands
        // Tool shortcuts on welcome screen need NSEvent monitor
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard showWelcome, !event.modifierFlags.contains(.command) else { return event }

            let key = event.characters?.uppercased() ?? ""
            if let tool = settings.tools.first(where: { $0.shortcut.uppercased() == key }) {
                launchTool(tool)
                return nil
            }
            if key == "T" {
                manager.createSession(label: "Terminal", panel: .main)
                showWelcome = false
                return nil
            }
            if key == "S" {
                showSettings = true
                return nil
            }
            return event
        }
    }
}
