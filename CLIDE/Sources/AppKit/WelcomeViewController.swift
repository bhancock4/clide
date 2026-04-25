import AppKit

protocol WelcomeViewControllerDelegate: AnyObject {
    func welcomeDidSelectTool(_ tool: ToolConfig)
    func welcomeDidSelectNewTerminal()
    func welcomeDidSelectRestoreSession()
    func welcomeDidSelectSettings()
}

class WelcomeViewController: NSViewController {
    weak var delegate: WelcomeViewControllerDelegate?
    private let settings: AppSettings
    private let hasSavedSession: Bool

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
        // Make window accept key events for shortcuts
        view.window?.makeFirstResponder(view)
    }

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard !event.modifierFlags.contains(.command) else {
            super.keyDown(with: event)
            return
        }
        let key = event.characters?.uppercased() ?? ""
        if let tool = settings.tools.first(where: { $0.shortcut.uppercased() == key }) {
            delegate?.welcomeDidSelectTool(tool)
            return
        }
        if key == "T" { delegate?.welcomeDidSelectNewTerminal(); return }
        if key == "S" { delegate?.welcomeDidSelectSettings(); return }
        super.keyDown(with: event)
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

        // ASCII Logo
        let logo = makeLabel(asciiLogo, font: NSFont.monospacedSystemFont(ofSize: 10, weight: .regular), color: Theme.accentGold, align: .center)
        stack.addArrangedSubview(logo)

        // Subtitle
        let subtitle = makeLabel("Command Line Integrated Development Environment", font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular), color: Theme.textSecondary, align: .center)
        stack.addArrangedSubview(subtitle)

        // Clyde
        let clyde = makeLabel(clydeMascot, font: Theme.fontTiny, color: Theme.textMuted, align: .center)
        stack.addArrangedSubview(clyde)

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
            self?.delegate?.welcomeDidSelectNewTerminal()
        }
        buttonRow.addArrangedSubview(termBtn)
        stack.addArrangedSubview(buttonRow)

        // Hints
        let hints = makeLabel("[T] New Terminal  [S] Settings  [?] Help", font: Theme.fontSmall, color: Theme.textMuted, align: .center)
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
            // Just dismiss — do nothing, the welcome screen stays with tools
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
            self?.delegate?.welcomeDidSelectTool(tool)
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

    // MARK: - Branding text

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
