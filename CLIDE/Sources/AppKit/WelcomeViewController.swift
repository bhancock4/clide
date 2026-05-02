import AppKit

protocol WelcomeViewControllerDelegate: AnyObject {
    func welcomeDidSelectTool(_ tool: ToolConfig)
    func welcomeDidSelectNewTerminal()
    func welcomeDidSelectRestoreSession()
    func welcomeDidSelectSettings()
    func welcomeDidSelectLayout(_ layout: TerminalLayout)
}

class WelcomeViewController: NSViewController {
    weak var delegate: WelcomeViewControllerDelegate?
    private let settings: AppSettings
    private let hasSavedSession: Bool
    private var clydeLabel: NSTextField?
    private var tipLabel: NSTextField?
    private var animator: ClydeAnimator?

    init(settings: AppSettings, hasSavedSession: Bool) {
        self.settings = settings
        self.hasSavedSession = hasSavedSession
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 900, height: 600))
        container.wantsLayer = true
        container.layer?.backgroundColor = Theme.bgPrimary.cgColor
        self.view = container
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.makeFirstResponder(view)
        animator?.startIdleAnimation()
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        animator?.stop()
    }

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard !event.modifierFlags.contains(.command) else {
            super.keyDown(with: event)
            return
        }
        let key = event.characters?.uppercased() ?? ""
        if let tool = settings.tools.first(where: { $0.shortcut.uppercased() == key }) {
            launchWithChomp { [weak self] in self?.delegate?.welcomeDidSelectTool(tool) }
            return
        }
        if key == "T" { launchWithChomp { [weak self] in self?.delegate?.welcomeDidSelectNewTerminal() }; return }
        if key == "S" { delegate?.welcomeDidSelectSettings(); return }
        if key == "L" {
            if let layout = settings.defaultLayout {
                launchWithChomp { [weak self] in self?.delegate?.welcomeDidSelectLayout(layout) }
            }
            return
        }
        super.keyDown(with: event)
    }

    /// Play chomp animation then call the launch action.
    private func launchWithChomp(_ action: @escaping () -> Void) {
        animator?.playChomp { action() }
    }

    private func buildUI() {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -40),
        ])

        // ASCII Logo — taller font
        let logo = makeLabel(asciiLogo, font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular), color: Theme.accentGold, align: .center)
        stack.addArrangedSubview(logo)

        // Subtitle
        let subtitle = makeLabel("Command Line Integrated Development Environment", font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular), color: Theme.textSecondary, align: .center)
        stack.addArrangedSubview(subtitle)

        // Clyde + tip in a horizontal row (tip comes out of his mouth to the right)
        let clydeRow = NSStackView()
        clydeRow.orientation = .horizontal
        clydeRow.alignment = .centerY
        clydeRow.spacing = 12

        let clyde = makeLabel(ClydeFrames.idle, font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular), color: Theme.accentGold, align: .left)
        clydeRow.addArrangedSubview(clyde)
        self.clydeLabel = clyde

        // Tip label — to the right of Clyde's mouth
        let tip = NSTextField(labelWithString: "")
        tip.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        tip.textColor = Theme.textSecondary
        tip.alignment = .left
        tip.maximumNumberOfLines = 2
        tip.lineBreakMode = .byWordWrapping
        tip.translatesAutoresizingMaskIntoConstraints = false
        tip.setContentHuggingPriority(.defaultLow, for: .horizontal)
        NSLayoutConstraint.activate([
            tip.widthAnchor.constraint(lessThanOrEqualToConstant: 400),
        ])
        clydeRow.addArrangedSubview(tip)
        self.tipLabel = tip

        stack.addArrangedSubview(clydeRow)
        self.animator = ClydeAnimator(clydeLabel: clyde, tipLabel: tip)

        // Session restore prompt
        if hasSavedSession {
            let restoreBox = buildSessionPrompt()
            stack.addArrangedSubview(restoreBox)
        }

        // Quick Launch title
        let qlTitle = makeLabel("QUICK LAUNCH", font: Theme.fontSmall, color: Theme.textSecondary, align: .center)
        stack.addArrangedSubview(qlTitle)

        // Tool buttons row
        let buttonRow = NSStackView()
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 12

        for tool in settings.tools {
            let btn = makeToolButton(tool)
            buttonRow.addArrangedSubview(btn)
        }
        let termBtn = makeButton(shortcut: "T", label: "Terminal") { [weak self] in
            self?.launchWithChomp { self?.delegate?.welcomeDidSelectNewTerminal() }
        }
        buttonRow.addArrangedSubview(termBtn)
        stack.addArrangedSubview(buttonRow)

        // Saved layouts
        if let layouts = settings.layouts, !layouts.isEmpty {
            let layoutTitle = makeLabel("LAYOUTS", font: Theme.fontSmall, color: Theme.textSecondary, align: .center)
            stack.addArrangedSubview(layoutTitle)

            let layoutRow = NSStackView()
            layoutRow.orientation = .horizontal
            layoutRow.spacing = 12
            for layout in layouts {
                let prefix = layout.isDefault ? "[L] " : ""
                let btn = makeActionButton("\(prefix)\(layout.name)", highlight: layout.isDefault) { [weak self] in
                    self?.launchWithChomp { self?.delegate?.welcomeDidSelectLayout(layout) }
                }
                layoutRow.addArrangedSubview(btn)
            }
            stack.addArrangedSubview(layoutRow)
        }

        // Hints
        let hintsText = settings.layouts?.isEmpty == false
            ? "[T] New Terminal  [L] Default Layout  [S] Settings"
            : "[T] New Terminal  [S] Settings  [?] Help"
        let hints = makeLabel(hintsText, font: Theme.fontSmall, color: Theme.textMuted, align: .center)
        stack.addArrangedSubview(hints)
    }

    private func buildSessionPrompt() -> NSView {
        let box = NSView()
        box.wantsLayer = true
        box.layer?.backgroundColor = Theme.bgSecondary.cgColor
        box.layer?.borderColor = Theme.accentGold.cgColor
        box.layer?.borderWidth = 1
        box.layer?.cornerRadius = 8

        let innerStack = NSStackView()
        innerStack.orientation = .vertical
        innerStack.alignment = .centerX
        innerStack.spacing = 10
        innerStack.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(innerStack)

        NSLayoutConstraint.activate([
            innerStack.topAnchor.constraint(equalTo: box.topAnchor, constant: 14),
            innerStack.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -14),
            innerStack.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 20),
            innerStack.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -20),
        ])

        let title = makeLabel("Previous session found", font: Theme.font, color: Theme.textSecondary, align: .center)
        innerStack.addArrangedSubview(title)

        let btnRow = NSStackView()
        btnRow.orientation = .horizontal
        btnRow.spacing = 12

        let restoreBtn = makeActionButton("Restore Session", highlight: true) { [weak self] in
            self?.delegate?.welcomeDidSelectRestoreSession()
        }
        let newBtn = makeActionButton("New Session", highlight: false) { [weak self] in
            // Dismiss prompt — welcome screen stays
        }
        btnRow.addArrangedSubview(restoreBtn)
        btnRow.addArrangedSubview(newBtn)
        innerStack.addArrangedSubview(btnRow)

        return box
    }

    // MARK: - Helpers

    private func makeLabel(_ text: String, font: NSFont, color: NSColor, align: NSTextAlignment) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = font
        label.textColor = color
        label.alignment = align
        label.maximumNumberOfLines = 0
        return label
    }

    private func makeToolButton(_ tool: ToolConfig) -> NSButton {
        return makeButton(shortcut: tool.shortcut, label: tool.name) { [weak self] in
            self?.launchWithChomp { self?.delegate?.welcomeDidSelectTool(tool) }
        }
    }

    private func makeButton(shortcut: String, label: String, action: @escaping () -> Void) -> NSButton {
        let btn = CallbackButton(title: "[\(shortcut)] \(label)", action: action)
        btn.font = Theme.font
        btn.isBordered = false
        btn.wantsLayer = true
        btn.layer?.backgroundColor = Theme.bgSecondary.cgColor
        btn.layer?.borderColor = Theme.border.cgColor
        btn.layer?.borderWidth = 1
        btn.layer?.cornerRadius = 6
        btn.contentTintColor = Theme.textPrimary
        btn.widthAnchor.constraint(greaterThanOrEqualToConstant: 100).isActive = true
        btn.heightAnchor.constraint(equalToConstant: 36).isActive = true
        return btn
    }

    private func makeActionButton(_ title: String, highlight: Bool, action: @escaping () -> Void) -> NSButton {
        let btn = CallbackButton(title: title, action: action)
        btn.font = Theme.font
        btn.isBordered = false
        btn.wantsLayer = true
        btn.layer?.backgroundColor = highlight ? Theme.accentGold.withAlphaComponent(0.15).cgColor : Theme.bgTertiary.cgColor
        btn.layer?.borderColor = highlight ? Theme.accentGold.cgColor : Theme.border.cgColor
        btn.layer?.borderWidth = 1
        btn.layer?.cornerRadius = 6
        btn.contentTintColor = highlight ? Theme.accentGold : Theme.textPrimary
        btn.heightAnchor.constraint(equalToConstant: 34).isActive = true
        return btn
    }

    // MARK: - Logo

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
}

// MARK: - Clyde Animation Frames

enum ClydeFrames {
    // All lines padded to equal width so center alignment doesn't shift the vertical bar
    static let idle =
        "   ◉  ◉   \n" +
        " █████████╗\n" +
        "██╔═══════╝\n" +
        "██║        \n" +
        "██║        \n" +
        "╚█████████╗\n" +
        " ╚════════╝\n" +
        "   CLYDE   "

    static let blinkLeft =
        "   ─  ◉   \n" +
        " █████████╗\n" +
        "██╔═══════╝\n" +
        "██║        \n" +
        "██║        \n" +
        "╚█████████╗\n" +
        " ╚════════╝\n" +
        "   CLYDE   "

    static let blinkBoth =
        "   ─  ─   \n" +
        " █████████╗\n" +
        "██╔═══════╝\n" +
        "██║        \n" +
        "██║        \n" +
        "╚█████████╗\n" +
        " ╚════════╝\n" +
        "   CLYDE   "

    static let chompOpen =
        "   ◉  ◉   \n" +
        " █████████╗\n" +
        "██╔═══════╝·\n" +
        "██║         ·\n" +
        "██║         ·\n" +
        "╚█████████╗\n" +
        " ╚════════╝\n" +
        "   CLYDE   "

    static let chompWide =
        "   ◉  ◉    \n" +
        " █████████╗ \n" +
        "██╔═══════╝··\n" +
        "██║         ··\n" +
        "██║         ··\n" +
        "╚█████████╗ \n" +
        " ╚════════╝ \n" +
        "   CLYDE    "
}

// MARK: - Clyde Animator with Tips

class ClydeAnimator {
    private weak var clydeLabel: NSTextField?
    private weak var tipLabel: NSTextField?
    private var timer: Timer?
    private var isAnimating = false
    private var tipIndex = 0
    private var currentTipText = ""
    private var typewriterIndex = 0
    private var typewriterTimer: Timer?

    init(clydeLabel: NSTextField, tipLabel: NSTextField) {
        self.clydeLabel = clydeLabel
        self.tipLabel = tipLabel
        self.tipIndex = Int.random(in: 0..<ClydeTips.all.count)
    }

    func startIdleAnimation() {
        stop()
        // Start first tip after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.spitOutTip()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        typewriterTimer?.invalidate()
        typewriterTimer = nil
    }

    // MARK: - Tip Cycle: chomp → type out → wait 10s → retract → chomp → next

    private func spitOutTip() {
        guard !isAnimating else { return }
        isAnimating = true
        currentTipText = ClydeTips.all[tipIndex % ClydeTips.all.count]
        tipIndex += 1

        // Chomp animation
        let chompFrames = [ClydeFrames.chompOpen, ClydeFrames.idle, ClydeFrames.chompWide, ClydeFrames.idle]
        playFrames(chompFrames, index: 0, interval: 0.1) { [weak self] in
            self?.typeOutTip()
        }
    }

    private func typeOutTip() {
        typewriterIndex = 0
        tipLabel?.stringValue = ""
        typewriterTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            self.typewriterIndex += 1
            if self.typewriterIndex <= self.currentTipText.count {
                let idx = self.currentTipText.index(self.currentTipText.startIndex, offsetBy: self.typewriterIndex)
                self.tipLabel?.stringValue = String(self.currentTipText[..<idx])
            } else {
                timer.invalidate()
                self.waitThenRetract()
            }
        }
    }

    private func waitThenRetract() {
        // Blink occasionally while waiting
        var blinkCount = 0
        timer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { [weak self] t in
            blinkCount += 1
            if blinkCount >= 4 {
                t.invalidate()
                self?.retractTip()
            } else {
                self?.doBlink()
            }
        }
    }

    private func retractTip() {
        typewriterTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            if self.currentTipText.isEmpty {
                timer.invalidate()
                self.tipLabel?.stringValue = ""
                self.finishCycle()
                return
            }
            self.currentTipText.removeLast()
            self.tipLabel?.stringValue = self.currentTipText
        }
    }

    private func finishCycle() {
        // Chomp the text back up
        let chompFrames = [ClydeFrames.chompOpen, ClydeFrames.idle, ClydeFrames.chompOpen, ClydeFrames.idle]
        playFrames(chompFrames, index: 0, interval: 0.1) { [weak self] in
            self?.isAnimating = false
            // Pause then start next tip
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.spitOutTip()
            }
        }
    }

    private func doBlink() {
        let blinkFrame = Bool.random() ? ClydeFrames.blinkLeft : ClydeFrames.blinkBoth
        clydeLabel?.stringValue = blinkFrame
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.clydeLabel?.stringValue = ClydeFrames.idle
        }
    }

    func playChomp(completion: @escaping () -> Void) {
        stop()
        isAnimating = true
        tipLabel?.stringValue = ""

        let frames = [
            ClydeFrames.chompOpen, ClydeFrames.idle,
            ClydeFrames.chompWide, ClydeFrames.idle,
            ClydeFrames.chompOpen, ClydeFrames.blinkBoth,
        ]

        playFrames(frames, index: 0, interval: 0.1) { [weak self] in
            self?.clydeLabel?.stringValue = ClydeFrames.idle
            self?.isAnimating = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                completion()
            }
        }
    }

    private func playFrames(_ frames: [String], index: Int, interval: TimeInterval, completion: @escaping () -> Void) {
        guard index < frames.count else { completion(); return }
        clydeLabel?.stringValue = frames[index]
        DispatchQueue.main.asyncAfter(deadline: .now() + interval) { [weak self] in
            self?.playFrames(frames, index: index + 1, interval: interval, completion: completion)
        }
    }
}

// MARK: - Clyde Tips

enum ClydeTips {
    static let all = [
        "Cmd+\\ toggles a new column",
        "Cmd+N creates a new terminal",
        "Cmd+Shift+N adds a terminal in the next column",
        "Cmd+W closes the active terminal",
        "Cmd+Shift+[ and ] cycle between terminals",
        "Cmd+Return sends selected text to paired terminals",
        "Cmd+Shift+Return sends selection and runs it",
        "Drag a terminal header onto another to pair them",
        "Right-click a header to manage pairings",
        "Click the antenna icon to add a terminal to broadcast",
        "Broadcast sends your keystrokes to all lit-up terminals",
        "Double-click a terminal header to rename it",
        "Terminal numbers are stable — they never renumber",
        "Save your layout from File > Save Layout...",
        "Set a default layout in Settings — it loads on startup",
        "Switch layouts mid-session from View > Switch Layout",
        "Layouts remember window size and position",
        "Layouts can include terminal pairings",
        "Use --layout \"name\" to launch with a specific layout",
        "Press L on the home screen to load the default layout",
        "Paired terminals show colored stripes in their headers",
        "The selection bar appears when you select text in split view",
        "Click the dropdown in the selection bar to pick targets",
        "Use the checkbox popover to send to multiple terminals",
        "Any column can add another column to its right",
        "Empty columns auto-close when their last terminal exits",
        "Right-click in a terminal for the send-to context menu",
        "Send to All Paired sends to every paired terminal at once",
        "Each column has its own + button for adding terminals",
        "The home button saves your session and returns here",
        "Sessions are auto-saved when you quit",
        "Cmd+, opens Settings",
        "You can set a default working directory in Settings",
        "Toggle 'Prompt for directory' to choose per terminal",
        "Font size and color are configurable in Settings",
        "Tools are configured in settings.json",
        "Each tool has a keyboard shortcut on the home screen",
        "The C, G, A, O, U keys quick-launch configured tools",
        "Dragging between terminal headers creates a pairing",
        "The gold left bar shows which terminal has keyboard focus",
        "Broadcast is independent of pairing — use both together",
        "Clear broadcast from the right-click menu",
        "Terminal columns have draggable dividers for resizing",
        "Terminals within a column also have draggable dividers",
        "The window position and size persist across sessions",
        "Clyde is the CLIDE mascot — that's me!",
        "CLIDE = Command Line Integrated Development Environment",
        "You can have unlimited columns and terminals",
        "The layout editor lets you design grid configurations",
        "In the layout editor, click the link icon to pair cells",
        "Manage layouts from Settings > Manage Layouts",
        "Set any layout as default with the Set Default button",
        "Delete layouts you don't need from the Settings panel",
        "The selection bar shows Send and Run as separate actions",
        "Send pastes text, Run pastes and hits Enter",
        "Unpair terminals from the right-click header menu",
        "Unpair All removes all pairings for a terminal",
        "Broadcast mode: type once, it goes everywhere",
        "Each terminal runs a full login shell for proper PATH",
        "Tools launch by sending the command after shell init",
        "The 0.5s delay before tool launch ensures PATH is ready",
        "Terminal process exit auto-closes the terminal",
        "Restored sessions recreate your entire workspace",
        "The subtitle bar shows the active terminal's title",
        "Columns get sidebar, +, settings, and home buttons",
        "Non-primary columns get + and close buttons",
        "SF Symbols are used throughout the UI for crisp icons",
        "The dark theme uses a navy-blue palette for contrast",
        "Gold (#C9A227) is the primary accent color",
        "Amber (#F59E0B) is used for broadcast indicators",
        "Green indicates executable actions (Run, Send & Run)",
        "Red indicates destructive actions (delete, unpair all)",
        "The app icon is a blocky golden C with Clippy-style eyes",
        "Press S on the home screen to open Settings",
        "Press T on the home screen for a plain terminal",
        "Pair a terminal with two others for fan-out commands",
        "The selection bar remembers your target choices per session",
        "Multiple pairing groups can overlap on the same terminal",
        "Pairing stripes stack — one color per group membership",
        "Right-click context menus are available on all headers",
        "Broadcast Input in the right-click menu toggles a terminal",
        "Clear Broadcast Group removes all terminals from broadcast",
        "Settings changes take effect immediately",
        "The app supports dark backgrounds by default",
        "Block characters (██) create the retro terminal aesthetic",
        "Box-drawing characters (╔═╗║╚═╝) add structure to ASCII art",
        "Clyde blinks when idle and chomps when launching tools",
        "I'm watching... just kidding. Type away!",
        "Pro tip: pair Claude with a plain terminal for testing",
        "Pair two AI tools to compare their responses side by side",
        "Use broadcast to run the same git command in all repos",
        "Broadcast + multiple terminals = parallel deployment",
        "The layout editor supports any number of columns and rows",
        "Tip: one column for AI, one for code, one for tests",
        "Three-column layout: Claude | Editor | Terminal",
        "Save different layouts for different project types",
        "I may be made of blocks, but I have feelings too",
        "Fun fact: Clyde is named after the CLIDE app, not vice versa",
        "The settings file lives in ~/Library/Application Support/com.clide.app/",
        "Want more tips? There are exactly 100 of them!",
    ]
}

// MARK: - CallbackButton

/// Simple NSButton subclass that calls a closure on click.
class CallbackButton: NSButton {
    private var callback: (() -> Void)?

    convenience init(title: String, action: @escaping () -> Void) {
        self.init(title: title, target: nil, action: nil)
        self.callback = action
        self.target = self
        self.action = #selector(clicked)
    }

    @objc private func clicked() {
        callback?()
    }
}
