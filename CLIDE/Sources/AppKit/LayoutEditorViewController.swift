import AppKit

/// Visual layout editor — modal sheet for designing terminal grid layouts.
class LayoutEditorViewController: NSViewController {
    var layout: TerminalLayout
    var tools: [ToolConfig]
    var onSave: ((TerminalLayout) -> Void)?
    var onDelete: ((UUID) -> Void)?

    private let nameField = NSTextField()
    private let defaultCheckbox = NSButton(checkboxWithTitle: "Default layout", target: nil, action: nil)
    private var gridContainer = NSStackView()
    private var pairingsContainer = NSStackView()
    private var isEditing: Bool
    private var pairingSelection: LayoutPosition?  // first cell selected for pairing

    private let pairingColors = [
        "#e06c75", "#98c379", "#61afef", "#c678dd",
        "#e5c07b", "#56b6c2", "#be5046", "#d19a66"
    ]

    init(layout: TerminalLayout?, tools: [ToolConfig]) {
        self.layout = layout ?? TerminalLayout(
            name: "",
            columns: [LayoutColumn(terminals: [LayoutTerminal()])]
        )
        self.tools = tools
        self.isEditing = layout != nil
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 640, height: 560))
        container.wantsLayer = true
        container.layer?.backgroundColor = Theme.bgPrimary.cgColor
        self.view = container
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
    }

    private func buildUI() {
        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        view.addSubview(scroll)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 14
        root.translatesAutoresizingMaskIntoConstraints = false
        root.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)

        let clipView = NSClipView()
        clipView.documentView = root
        clipView.drawsBackground = false
        scroll.contentView = clipView

        NSLayoutConstraint.activate([
            root.widthAnchor.constraint(equalTo: scroll.widthAnchor, constant: -40),
        ])

        // Title
        let title = NSTextField(labelWithString: "Layout Editor")
        title.font = NSFont.monospacedSystemFont(ofSize: 16, weight: .bold)
        title.textColor = Theme.accentGold
        root.addArrangedSubview(title)

        // Name row
        let nameRow = NSStackView()
        nameRow.orientation = .horizontal
        nameRow.spacing = 8
        let nameLabel = NSTextField(labelWithString: "Name:")
        nameLabel.font = Theme.font
        nameLabel.textColor = Theme.textSecondary
        nameField.stringValue = layout.name
        nameField.font = Theme.font
        nameField.placeholderString = "My Layout"
        nameField.translatesAutoresizingMaskIntoConstraints = false
        nameField.widthAnchor.constraint(equalToConstant: 200).isActive = true
        defaultCheckbox.state = layout.isDefault ? .on : .off
        defaultCheckbox.font = Theme.fontSmall
        defaultCheckbox.contentTintColor = Theme.textSecondary
        nameRow.addArrangedSubview(nameLabel)
        nameRow.addArrangedSubview(nameField)
        nameRow.addArrangedSubview(defaultCheckbox)
        root.addArrangedSubview(nameRow)

        // Grid section
        let gridLabel = NSTextField(labelWithString: "TERMINALS")
        gridLabel.font = Theme.fontSmall
        gridLabel.textColor = Theme.textSecondary
        root.addArrangedSubview(gridLabel)

        gridContainer.orientation = .horizontal
        gridContainer.alignment = .top
        gridContainer.spacing = 8
        gridContainer.translatesAutoresizingMaskIntoConstraints = false
        root.addArrangedSubview(gridContainer)
        rebuildGrid()

        // Pairings section
        let pairLabel = NSTextField(labelWithString: "PAIRINGS (click two cells above to pair them)")
        pairLabel.font = Theme.fontSmall
        pairLabel.textColor = Theme.textSecondary
        root.addArrangedSubview(pairLabel)

        pairingsContainer.orientation = .vertical
        pairingsContainer.alignment = .leading
        pairingsContainer.spacing = 6
        pairingsContainer.translatesAutoresizingMaskIntoConstraints = false
        root.addArrangedSubview(pairingsContainer)
        rebuildPairings()

        // Buttons
        let btnRow = NSStackView()
        btnRow.orientation = .horizontal
        btnRow.spacing = 12

        if isEditing {
            let deleteBtn = CallbackButton(title: "Delete", action: { [weak self] in self?.deleteLayout() })
            deleteBtn.font = Theme.font
            deleteBtn.contentTintColor = Theme.accentRed
            deleteBtn.isBordered = false
            btnRow.addArrangedSubview(deleteBtn)
        }

        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.widthAnchor.constraint(greaterThanOrEqualToConstant: 1).isActive = true
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        btnRow.addArrangedSubview(spacer)

        let cancelBtn = CallbackButton(title: "Cancel", action: { [weak self] in
            guard let self, let w = self.view.window, let parent = w.sheetParent else { return }
                parent.endSheet(w)
        })
        cancelBtn.font = Theme.font
        cancelBtn.isBordered = false
        cancelBtn.contentTintColor = Theme.textSecondary

        let saveBtn = CallbackButton(title: "Save", action: { [weak self] in self?.save() })
        saveBtn.font = Theme.font
        saveBtn.isBordered = false
        saveBtn.contentTintColor = Theme.accentGold
        saveBtn.wantsLayer = true
        saveBtn.layer?.backgroundColor = Theme.accentGold.withAlphaComponent(0.15).cgColor
        saveBtn.layer?.cornerRadius = 6

        btnRow.addArrangedSubview(cancelBtn)
        btnRow.addArrangedSubview(saveBtn)

        btnRow.translatesAutoresizingMaskIntoConstraints = false
        root.addArrangedSubview(btnRow)
        NSLayoutConstraint.activate([
            btnRow.widthAnchor.constraint(equalTo: root.widthAnchor),
        ])
    }

    // MARK: - Grid

    private func rebuildGrid() {
        gridContainer.arrangedSubviews.forEach { $0.removeFromSuperview() }

        for (colIdx, col) in layout.columns.enumerated() {
            let colStack = NSStackView()
            colStack.orientation = .vertical
            colStack.spacing = 4
            colStack.wantsLayer = true
            colStack.layer?.backgroundColor = Theme.bgSecondary.cgColor
            colStack.layer?.cornerRadius = 6
            colStack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

            let colLabel = NSTextField(labelWithString: "Column \(colIdx + 1)")
            colLabel.font = NSFont.systemFont(ofSize: 10, weight: .medium)
            colLabel.textColor = Theme.textMuted
            colStack.addArrangedSubview(colLabel)

            for (rowIdx, terminal) in col.terminals.enumerated() {
                let cellView = buildGridCell(terminal: terminal, column: colIdx, row: rowIdx)
                colStack.addArrangedSubview(cellView)
            }

            let addRowBtn = CallbackButton(title: "+ Terminal", action: { [weak self] in
                self?.addRow(toColumn: colIdx)
            })
            addRowBtn.font = NSFont.systemFont(ofSize: 11)
            addRowBtn.isBordered = false
            addRowBtn.contentTintColor = Theme.textMuted
            colStack.addArrangedSubview(addRowBtn)

            if layout.columns.count > 1 {
                let removeColBtn = CallbackButton(title: "Remove Column", action: { [weak self] in
                    self?.removeColumn(colIdx)
                })
                removeColBtn.font = NSFont.systemFont(ofSize: 10)
                removeColBtn.isBordered = false
                removeColBtn.contentTintColor = Theme.accentRed
                colStack.addArrangedSubview(removeColBtn)
            }

            colStack.translatesAutoresizingMaskIntoConstraints = false
            colStack.widthAnchor.constraint(equalToConstant: 160).isActive = true
            gridContainer.addArrangedSubview(colStack)
        }

        let addColBtn = CallbackButton(title: "+\nColumn", action: { [weak self] in self?.addColumn() })
        addColBtn.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        addColBtn.isBordered = false
        addColBtn.contentTintColor = Theme.textMuted
        addColBtn.wantsLayer = true
        addColBtn.layer?.backgroundColor = Theme.bgSecondary.cgColor
        addColBtn.layer?.cornerRadius = 6
        addColBtn.layer?.borderColor = Theme.border.cgColor
        addColBtn.layer?.borderWidth = 1
        addColBtn.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            addColBtn.widthAnchor.constraint(equalToConstant: 60),
            addColBtn.heightAnchor.constraint(equalToConstant: 60),
        ])
        gridContainer.addArrangedSubview(addColBtn)
    }

    private func buildGridCell(terminal: LayoutTerminal, column: Int, row: Int) -> NSView {
        let pos = LayoutPosition(column: column, row: row)
        let isPairingSelected = pairingSelection == pos
        let pairingColors = pairingColorsFor(pos)

        let cell = NSView()
        cell.wantsLayer = true
        cell.layer?.backgroundColor = isPairingSelected
            ? Theme.accentGold.withAlphaComponent(0.2).cgColor
            : Theme.bgTertiary.cgColor
        cell.layer?.cornerRadius = 4
        if !pairingColors.isEmpty {
            cell.layer?.borderColor = (NSColor.fromHex(pairingColors[0]) ?? Theme.accentGold).cgColor
            cell.layer?.borderWidth = 2
        } else if isPairingSelected {
            cell.layer?.borderColor = Theme.accentGold.cgColor
            cell.layer?.borderWidth = 2
        }

        let popup = NSPopUpButton()
        popup.font = NSFont.systemFont(ofSize: 11)
        popup.addItem(withTitle: "Terminal")
        popup.lastItem?.representedObject = ""
        for tool in tools {
            popup.addItem(withTitle: tool.name)
            popup.lastItem?.representedObject = tool.command
        }
        if terminal.command.isEmpty {
            popup.selectItem(at: 0)
        } else if let idx = tools.firstIndex(where: { $0.command == terminal.command }) {
            popup.selectItem(at: idx + 1)
        }
        popup.target = self
        popup.action = #selector(cellToolChanged(_:))
        popup.tag = column * 100 + row

        // Pair button — click to select this cell for pairing
        let pairBtn = NSButton(title: "", target: nil, action: nil)
        pairBtn.image = NSImage(systemSymbolName: "link", accessibilityDescription: "Pair")
        pairBtn.imagePosition = .imageOnly
        pairBtn.symbolConfiguration = .init(pointSize: 10, weight: .medium)
        pairBtn.isBordered = false
        pairBtn.contentTintColor = isPairingSelected ? Theme.accentGold : Theme.textMuted
        pairBtn.toolTip = "Click to pair with another terminal"
        BlockTarget.shared.register(pairBtn) { [weak self] in
            self?.cellClickedForPairing(column: column, row: row)
        }

        let removeBtn = CallbackButton(title: "✕", action: { [weak self] in
            self?.removeRow(column: column, row: row)
        })
        removeBtn.font = NSFont.systemFont(ofSize: 9)
        removeBtn.isBordered = false
        removeBtn.contentTintColor = Theme.textMuted

        let stack = NSStackView(views: [popup, pairBtn, removeBtn])
        stack.orientation = .horizontal
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: cell.topAnchor, constant: 4),
            stack.bottomAnchor.constraint(equalTo: cell.bottomAnchor, constant: -4),
            stack.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
            stack.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
        ])

        return cell
    }

    /// Returns hex colors of pairings that include this position.
    private func pairingColorsFor(_ pos: LayoutPosition) -> [String] {
        layout.pairings.filter { $0.members.contains(pos) }.map(\.color)
    }

    // MARK: - Pairing UI

    private func cellClickedForPairing(column: Int, row: Int) {
        let pos = LayoutPosition(column: column, row: row)

        if let first = pairingSelection {
            if first == pos {
                // Deselect
                pairingSelection = nil
            } else {
                // Create pairing between first and pos
                let color = pairingColors[layout.pairings.count % pairingColors.count]
                let pairing = LayoutPairing(color: color, members: [first, pos])
                layout.pairings.append(pairing)
                pairingSelection = nil
            }
        } else {
            pairingSelection = pos
        }

        rebuildGrid()
        rebuildPairings()
    }

    private func rebuildPairings() {
        pairingsContainer.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if layout.pairings.isEmpty {
            let empty = NSTextField(labelWithString: "No pairings yet. Click 🔗 on two cells to pair them.")
            empty.font = Theme.fontSmall
            empty.textColor = Theme.textMuted
            pairingsContainer.addArrangedSubview(empty)
            return
        }

        for (idx, pairing) in layout.pairings.enumerated() {
            let row = NSStackView()
            row.orientation = .horizontal
            row.spacing = 8

            // Color dot
            let dot = NSView()
            dot.wantsLayer = true
            dot.layer?.backgroundColor = (NSColor.fromHex(pairing.color) ?? .gray).cgColor
            dot.layer?.cornerRadius = 5
            dot.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: 10),
                dot.heightAnchor.constraint(equalToConstant: 10),
            ])
            row.addArrangedSubview(dot)

            // Members description
            let desc = pairing.members.map { "C\($0.column+1)R\($0.row+1)" }.joined(separator: " ↔ ")
            let label = NSTextField(labelWithString: desc)
            label.font = Theme.fontSmall
            label.textColor = Theme.textPrimary
            row.addArrangedSubview(label)

            // Remove button
            let removeBtn = CallbackButton(title: "✕", action: { [weak self] in
                self?.layout.pairings.remove(at: idx)
                self?.rebuildGrid()
                self?.rebuildPairings()
            })
            removeBtn.font = NSFont.systemFont(ofSize: 9)
            removeBtn.isBordered = false
            removeBtn.contentTintColor = Theme.accentRed
            row.addArrangedSubview(removeBtn)

            pairingsContainer.addArrangedSubview(row)
        }
    }

    // MARK: - Grid Actions

    @objc private func cellToolChanged(_ sender: NSPopUpButton) {
        let col = sender.tag / 100
        let row = sender.tag % 100
        guard col < layout.columns.count, row < layout.columns[col].terminals.count else { return }

        let command = sender.selectedItem?.representedObject as? String ?? ""
        let toolName = sender.titleOfSelectedItem ?? "Terminal"

        layout.columns[col].terminals[row].command = command
        layout.columns[col].terminals[row].label = toolName
        if let tool = tools.first(where: { $0.command == command }) {
            layout.columns[col].terminals[row].args = tool.args
        } else {
            layout.columns[col].terminals[row].args = []
        }
    }

    private func addColumn() {
        layout.columns.append(LayoutColumn(terminals: [LayoutTerminal()]))
        rebuildGrid()
    }

    private func removeColumn(_ col: Int) {
        guard layout.columns.count > 1 else { return }
        // Remove pairings referencing this column
        layout.pairings.removeAll { $0.members.contains(where: { $0.column == col }) }
        layout.columns.remove(at: col)
        rebuildGrid()
        rebuildPairings()
    }

    private func addRow(toColumn col: Int) {
        guard col < layout.columns.count else { return }
        layout.columns[col].terminals.append(LayoutTerminal())
        rebuildGrid()
    }

    private func removeRow(column: Int, row: Int) {
        guard column < layout.columns.count,
              layout.columns[column].terminals.count > 1 else { return }
        // Remove pairings referencing this cell
        let pos = LayoutPosition(column: column, row: row)
        layout.pairings.removeAll { $0.members.contains(pos) }
        layout.columns[column].terminals.remove(at: row)
        rebuildGrid()
        rebuildPairings()
    }

    // MARK: - Save / Delete

    private func save() {
        let name = nameField.stringValue.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else {
            let alert = NSAlert()
            alert.messageText = "Please enter a layout name."
            alert.runModal()
            return
        }
        layout.name = name
        layout.isDefault = defaultCheckbox.state == .on
        onSave?(layout)
        view.window?.sheetParent?.endSheet(view.window!)
    }

    private func deleteLayout() {
        let alert = NSAlert()
        alert.messageText = "Delete layout \"\(layout.name)\"?"
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            onDelete?(layout.id)
            view.window?.sheetParent?.endSheet(view.window!)
        }
    }

    // MARK: - Static presentation

    static func show(in window: NSWindow, layout: TerminalLayout?, tools: [ToolConfig], onSave: @escaping (TerminalLayout) -> Void, onDelete: ((UUID) -> Void)? = nil) {
        let vc = LayoutEditorViewController(layout: layout, tools: tools)
        vc.onSave = onSave
        vc.onDelete = onDelete

        let sheetWindow = NSWindow(contentViewController: vc)
        sheetWindow.styleMask = [.titled, .closable]
        sheetWindow.title = layout == nil ? "New Layout" : "Edit Layout"
        window.beginSheet(sheetWindow)
    }
}
