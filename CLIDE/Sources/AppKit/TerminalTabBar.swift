import AppKit

// MARK: - Terminal Cell Delegate

protocol TerminalCellDelegate: AnyObject {
    func cellDidSelect(_ id: UUID)
    func cellDidClose(_ id: UUID)
    func cellDidDoubleClick(_ id: UUID)
    func cellDidToggleBroadcast(_ id: UUID)
    func cellDidRequestPairing(source: UUID, target: UUID)
    func cellDidRightClick(_ id: UUID, event: NSEvent, view: NSView)
}

// MARK: - Pasteboard type for drag & drop pairing

extension NSPasteboard.PasteboardType {
    static let clideSessionId = NSPasteboard.PasteboardType("com.clide.session-id")
}

// MARK: - Terminal Cell Header

/// Thin header bar for a stacked terminal cell — shows colored dot, label, close button, and pairing stripes.
class TerminalCellHeader: NSView, NSDraggingSource {
    let sessionId: UUID
    weak var delegate: TerminalCellDelegate?
    private let labelField = NSTextField(labelWithString: "")
    private let dot = NSView()
    private let stripesStack = NSStackView()
    private let broadcastBtn = NSButton()
    private var mouseDownLocation: NSPoint?
    private var isDragging = false

    var isActive: Bool = false {
        didSet { updateAppearance() }
    }

    var isBroadcasting: Bool = false {
        didSet { updateBroadcastAppearance() }
    }

    init(sessionId: UUID, label: String, color: NSColor, delegate: TerminalCellDelegate?) {
        self.sessionId = sessionId
        self.delegate = delegate
        super.init(frame: .zero)
        setup(label: label, color: color)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            registerForDraggedTypes([.clideSessionId])
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    func updateLabel(_ text: String) {
        labelField.stringValue = text
    }

    func updateColor(_ color: NSColor) {
        dot.layer?.backgroundColor = color.cgColor
    }

    func updatePairings(_ groups: [SessionManager.PairingGroup]) {
        stripesStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for group in groups {
            let stripe = NSView()
            stripe.wantsLayer = true
            stripe.layer?.backgroundColor = (NSColor.fromHex(group.color) ?? .gray).cgColor
            stripe.layer?.cornerRadius = 2
            stripe.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                stripe.widthAnchor.constraint(equalToConstant: 20),
                stripe.heightAnchor.constraint(equalToConstant: 4),
            ])
            stripesStack.addArrangedSubview(stripe)
        }
        stripesStack.isHidden = groups.isEmpty
    }

    private func setup(label: String, color: NSColor) {
        wantsLayer = true
        updateAppearance()

        // Pairing stripes at very top
        stripesStack.orientation = .horizontal
        stripesStack.spacing = 3
        stripesStack.translatesAutoresizingMaskIntoConstraints = false
        stripesStack.isHidden = true
        addSubview(stripesStack)

        dot.wantsLayer = true
        dot.layer?.backgroundColor = color.cgColor
        dot.layer?.cornerRadius = 4
        dot.translatesAutoresizingMaskIntoConstraints = false
        addSubview(dot)

        labelField.stringValue = label
        labelField.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        labelField.textColor = Theme.textSecondary
        labelField.lineBreakMode = .byTruncatingTail
        labelField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(labelField)

        // Broadcast toggle button — always visible, click to toggle
        broadcastBtn.image = NSImage(systemSymbolName: "antenna.radiowaves.left.and.right", accessibilityDescription: "Toggle Broadcast")
        broadcastBtn.imagePosition = .imageOnly
        broadcastBtn.symbolConfiguration = .init(pointSize: 9, weight: .medium)
        broadcastBtn.isBordered = false
        broadcastBtn.contentTintColor = Theme.textMuted
        broadcastBtn.toolTip = "Toggle broadcast input"
        broadcastBtn.target = self
        broadcastBtn.action = #selector(broadcastTapped)
        broadcastBtn.translatesAutoresizingMaskIntoConstraints = false
        addSubview(broadcastBtn)

        let closeBtn = NSButton(title: "", target: self, action: #selector(closeTapped))
        closeBtn.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close")
        closeBtn.imagePosition = .imageOnly
        closeBtn.symbolConfiguration = .init(pointSize: 8, weight: .medium)
        closeBtn.isBordered = false
        closeBtn.contentTintColor = Theme.textMuted
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        addSubview(closeBtn)

        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 28),

            stripesStack.topAnchor.constraint(equalTo: topAnchor, constant: 1),
            stripesStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            stripesStack.heightAnchor.constraint(equalToConstant: 4),

            dot.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            dot.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 2),
            dot.widthAnchor.constraint(equalToConstant: 8),
            dot.heightAnchor.constraint(equalToConstant: 8),

            labelField.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 6),
            labelField.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 2),
            labelField.trailingAnchor.constraint(lessThanOrEqualTo: broadcastBtn.leadingAnchor, constant: -4),

            broadcastBtn.trailingAnchor.constraint(equalTo: closeBtn.leadingAnchor, constant: -4),
            broadcastBtn.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 2),
            broadcastBtn.widthAnchor.constraint(equalToConstant: 16),
            broadcastBtn.heightAnchor.constraint(equalToConstant: 16),

            closeBtn.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            closeBtn.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 2),
            closeBtn.widthAnchor.constraint(equalToConstant: 16),
            closeBtn.heightAnchor.constraint(equalToConstant: 16),
        ])
    }

    private let activeIndicator = NSView()

    private func setupActiveIndicator() {
        activeIndicator.wantsLayer = true
        activeIndicator.layer?.backgroundColor = Theme.accentGold.cgColor
        activeIndicator.translatesAutoresizingMaskIntoConstraints = false
        activeIndicator.isHidden = true
        addSubview(activeIndicator)
        NSLayoutConstraint.activate([
            activeIndicator.leadingAnchor.constraint(equalTo: leadingAnchor),
            activeIndicator.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            activeIndicator.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            activeIndicator.widthAnchor.constraint(equalToConstant: 3),
        ])
    }

    private func updateAppearance() {
        if activeIndicator.superview == nil { setupActiveIndicator() }
        if isActive {
            layer?.backgroundColor = Theme.bgTertiary.cgColor
            labelField.textColor = Theme.textPrimary
            activeIndicator.isHidden = false
        } else {
            layer?.backgroundColor = Theme.bgSecondary.cgColor
            labelField.textColor = Theme.textSecondary
            activeIndicator.isHidden = true
        }
    }

    // MARK: - Mouse Events (with drag threshold)

    override func mouseDown(with event: NSEvent) {
        mouseDownLocation = event.locationInWindow
        isDragging = false

        if event.clickCount == 2 {
            delegate?.cellDidDoubleClick(sessionId)
            mouseDownLocation = nil
        }
    }

    override func mouseUp(with event: NSEvent) {
        // Only select if we didn't start a drag
        if !isDragging && mouseDownLocation != nil {
            delegate?.cellDidSelect(sessionId)
        }
        mouseDownLocation = nil
        isDragging = false
    }

    @objc func closeTapped() {
        delegate?.cellDidClose(sessionId)
    }

    @objc func broadcastTapped() {
        delegate?.cellDidToggleBroadcast(sessionId)
    }

    private func updateBroadcastAppearance() {
        broadcastBtn.contentTintColor = isBroadcasting ? Theme.accentAmber : Theme.textMuted
    }

    // MARK: - Right-Click Menu

    override func rightMouseDown(with event: NSEvent) {
        delegate?.cellDidRightClick(sessionId, event: event, view: self)
    }

    // MARK: - Drag Source (for pairing)

    override func mouseDragged(with event: NSEvent) {
        guard let startLoc = mouseDownLocation else { return }
        let currentLoc = event.locationInWindow
        let dx = currentLoc.x - startLoc.x
        let dy = currentLoc.y - startLoc.y
        let distance = sqrt(dx * dx + dy * dy)
        guard distance > 5 else { return }  // threshold before drag starts

        isDragging = true
        mouseDownLocation = nil  // prevent re-triggering

        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setString(sessionId.uuidString, forType: .clideSessionId)
        let dragItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
        dragItem.setDraggingFrame(bounds, contents: snapshot())
        beginDraggingSession(with: [dragItem], event: event, source: self)
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .link
    }

    private func snapshot() -> NSImage {
        let image = NSImage(size: bounds.size)
        image.lockFocus()
        if let ctx = NSGraphicsContext.current?.cgContext {
            layer?.render(in: ctx)
        }
        image.unlockFocus()
        return image
    }

    // MARK: - Drop Target (for pairing)

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard let sourceId = sender.draggingPasteboard.string(forType: .clideSessionId),
              UUID(uuidString: sourceId) != sessionId else {
            return []
        }
        layer?.borderColor = Theme.accentGold.cgColor
        layer?.borderWidth = 2
        return .link
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        layer?.borderWidth = 0
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        layer?.borderWidth = 0
        guard let sourceIdStr = sender.draggingPasteboard.string(forType: .clideSessionId),
              let sourceId = UUID(uuidString: sourceIdStr),
              sourceId != sessionId else {
            return false
        }
        delegate?.cellDidRequestPairing(source: sourceId, target: sessionId)
        return true
    }
}
