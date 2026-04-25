import AppKit

protocol TerminalTabBarDelegate: AnyObject {
    func tabBarDidSelectTab(_ id: UUID)
    func tabBarDidCloseTab(_ id: UUID)
    func tabBarDidDoubleClickTab(_ id: UUID)
    func tabBarDidRequestNewTab()
}

/// Horizontal tab bar showing terminal sessions with colored dots.
class TerminalTabBar: NSView {
    weak var delegate: TerminalTabBarDelegate?

    private let scrollView = NSScrollView()
    private let stackView = NSStackView()
    private let addButton = CallbackButton(title: "+", action: {})

    struct TabInfo {
        let id: UUID
        let label: String
        let color: NSColor
        let isActive: Bool
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = Theme.bgSecondary.cgColor

        stackView.orientation = .horizontal
        stackView.spacing = 2
        stackView.edgeInsets = NSEdgeInsets(top: 0, left: 4, bottom: 0, right: 4)

        scrollView.documentView = stackView
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = false
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)

        addButton.font = NSFont.monospacedSystemFont(ofSize: 16, weight: .regular)
        addButton.isBordered = false
        addButton.contentTintColor = Theme.textSecondary
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.target = self
        addButton.action = #selector(addClicked)
        addSubview(addButton)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 32),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollView.trailingAnchor.constraint(equalTo: addButton.leadingAnchor, constant: -4),
            addButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            addButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            addButton.widthAnchor.constraint(equalToConstant: 28),
        ])
    }

    @objc private func addClicked() {
        delegate?.tabBarDidRequestNewTab()
    }

    func update(tabs: [TabInfo]) {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        for (index, tab) in tabs.enumerated() {
            let tabView = makeTab(tab, index: index)
            stackView.addArrangedSubview(tabView)
        }
    }

    private func makeTab(_ tab: TabInfo, index: Int) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = tab.isActive ? Theme.bgPrimary.cgColor : NSColor.clear.cgColor
        container.layer?.cornerRadius = 4

        let dot = NSView()
        dot.wantsLayer = true
        dot.layer?.backgroundColor = tab.color.cgColor
        dot.layer?.cornerRadius = 4

        let label = NSTextField(labelWithString: tab.label)
        label.font = Theme.fontSmall
        label.textColor = tab.isActive ? Theme.textPrimary : Theme.textSecondary
        label.lineBreakMode = .byTruncatingTail

        let numLabel = NSTextField(labelWithString: index < 9 ? "\(index + 1)" : "")
        numLabel.font = NSFont.monospacedSystemFont(ofSize: 9, weight: .regular)
        numLabel.textColor = Theme.textMuted

        let stack = NSStackView(views: [dot, label, numLabel])
        stack.orientation = .horizontal
        stack.spacing = 6
        stack.edgeInsets = NSEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            dot.widthAnchor.constraint(equalToConstant: 8),
            dot.heightAnchor.constraint(equalToConstant: 8),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        // Click gesture
        let click = TabClickGesture(target: self, action: #selector(tabClicked(_:)))
        click.tabId = tab.id
        container.addGestureRecognizer(click)

        // Double-click gesture
        let dblClick = TabClickGesture(target: self, action: #selector(tabDoubleClicked(_:)))
        dblClick.tabId = tab.id
        dblClick.numberOfClicksRequired = 2
        container.addGestureRecognizer(dblClick)

        return container
    }

    @objc private func tabClicked(_ gesture: TabClickGesture) {
        if let id = gesture.tabId {
            delegate?.tabBarDidSelectTab(id)
        }
    }

    @objc private func tabDoubleClicked(_ gesture: TabClickGesture) {
        if let id = gesture.tabId {
            delegate?.tabBarDidDoubleClickTab(id)
        }
    }
}

class TabClickGesture: NSClickGestureRecognizer {
    var tabId: UUID?
}
