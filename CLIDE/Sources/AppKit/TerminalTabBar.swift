import AppKit

protocol TerminalTabBarDelegate: AnyObject {
    func tabBarDidSelectTab(_ id: UUID)
    func tabBarDidCloseTab(_ id: UUID)
    func tabBarDidDoubleClickTab(_ id: UUID)
    func tabBarDidRequestNewTab()
}

/// Horizontal tab bar showing terminal sessions with colored dots and close buttons.
class TerminalTabBar: NSView {
    weak var delegate: TerminalTabBarDelegate?

    private let stackView = NSStackView()

    struct TabInfo {
        let id: UUID
        let label: String
        let color: NSColor
        let isActive: Bool
        let index: Int
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        wantsLayer = true

        stackView.orientation = .horizontal
        stackView.spacing = 1
        stackView.alignment = .centerY
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
            // Don't pin trailing — let it be as wide as its content
        ])
    }

    func update(tabs: [TabInfo]) {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        for tab in tabs {
            let tabView = makeTab(tab)
            stackView.addArrangedSubview(tabView)
        }
    }

    private func makeTab(_ tab: TabInfo) -> NSView {
        // Use a button-like clickable view
        let btn = TabButton(tabId: tab.id, delegate: delegate)
        btn.wantsLayer = true
        btn.layer?.backgroundColor = tab.isActive
            ? Theme.bgPrimary.cgColor
            : Theme.bgTertiary.withAlphaComponent(0.3).cgColor
        btn.layer?.cornerRadius = 4

        // Colored dot
        let dot = NSView()
        dot.wantsLayer = true
        dot.layer?.backgroundColor = tab.color.cgColor
        dot.layer?.cornerRadius = 4
        dot.translatesAutoresizingMaskIntoConstraints = false

        // Label
        let label = NSTextField(labelWithString: tab.label)
        label.font = Theme.fontSmall
        label.textColor = tab.isActive ? Theme.textPrimary : Theme.textSecondary
        label.lineBreakMode = .byTruncatingTail
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.translatesAutoresizingMaskIntoConstraints = false

        // Tab number
        let numLabel = NSTextField(labelWithString: tab.index < 9 ? "\(tab.index + 1)" : "")
        numLabel.font = NSFont.monospacedSystemFont(ofSize: 9, weight: .regular)
        numLabel.textColor = Theme.textMuted
        numLabel.translatesAutoresizingMaskIntoConstraints = false

        // Close button
        let closeBtn = NSButton(title: "✕", target: btn, action: #selector(TabButton.closeClicked))
        closeBtn.font = NSFont.systemFont(ofSize: 9)
        closeBtn.isBordered = false
        closeBtn.contentTintColor = Theme.textSecondary
        closeBtn.translatesAutoresizingMaskIntoConstraints = false

        btn.addSubview(dot)
        btn.addSubview(label)
        btn.addSubview(numLabel)
        btn.addSubview(closeBtn)

        btn.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            btn.heightAnchor.constraint(equalToConstant: 28),

            dot.leadingAnchor.constraint(equalTo: btn.leadingAnchor, constant: 10),
            dot.centerYAnchor.constraint(equalTo: btn.centerYAnchor),
            dot.widthAnchor.constraint(equalToConstant: 8),
            dot.heightAnchor.constraint(equalToConstant: 8),

            label.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 6),
            label.centerYAnchor.constraint(equalTo: btn.centerYAnchor),
            label.widthAnchor.constraint(lessThanOrEqualToConstant: 120),

            numLabel.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 4),
            numLabel.centerYAnchor.constraint(equalTo: btn.centerYAnchor),

            closeBtn.leadingAnchor.constraint(equalTo: numLabel.trailingAnchor, constant: 4),
            closeBtn.trailingAnchor.constraint(equalTo: btn.trailingAnchor, constant: -6),
            closeBtn.centerYAnchor.constraint(equalTo: btn.centerYAnchor),
        ])

        return btn
    }
}

/// A clickable tab view that handles single-click (select) and double-click (rename).
class TabButton: NSView {
    let tabId: UUID
    weak var delegate: TerminalTabBarDelegate?

    init(tabId: UUID, delegate: TerminalTabBarDelegate?) {
        self.tabId = tabId
        self.delegate = delegate
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            delegate?.tabBarDidDoubleClickTab(tabId)
        } else {
            delegate?.tabBarDidSelectTab(tabId)
        }
    }

    @objc func closeClicked() {
        delegate?.tabBarDidCloseTab(tabId)
    }
}
