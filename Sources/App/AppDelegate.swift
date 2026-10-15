import AppKit
import FinderSync

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem!
    private var window: NSWindow!
    private var openedFromMenu = false
    private var directory = FileManager.default.homeDirectoryForCurrentUser
    private let pathLabel = NSTextField(labelWithString: "")
    private let folderLabel = NSTextField(labelWithString: "")
    private let extensionLabel = NSTextField(labelWithString: "")
    private let extensionHint = NSTextField(labelWithString: "")
    private let extensionIcon = NSImageView()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        buildStatusMenu()
        buildWindow()
        if !openedFromMenu {
            showWindow(nil)
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        updateExtensionStatus()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        openedFromMenu = true
        for url in urls {
            do {
                if url.host == "move" {
                    try executeMove(MoveRequest(url: url))
                } else {
                    try execute(ActionRequest(url: url))
                }
            } catch {
                showError(error)
            }
        }
    }

    private func buildStatusMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "cursorarrow.click", accessibilityDescription: "右键小匣")
        statusItem.button?.toolTip = "右键小匣"
        let menu = NSMenu()
        let openItem = NSMenuItem(title: "打开右键小匣…", action: #selector(showWindow(_:)), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "退出右键小匣", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)
        statusItem.menu = menu
    }

    private func buildWindow() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 860, height: 680),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                          backing: .buffered, defer: false)
        window.title = "右键小匣"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified
        window.contentMinSize = NSSize(width: 860, height: 680)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()

        let content = window.contentView!
        let sidebar = SurfaceView(fill: WindowColors.sidebar, radius: 0)
        sidebar.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(sidebar)
        buildSidebar(in: sidebar)

        let heading = stack([
            label("为 Finder 添一点顺手", size: 12, weight: .medium, color: WindowColors.accent),
            label("常用操作，一匣收好。", size: 25, weight: .semibold)
        ], spacing: 8)
        let status = buildExtensionStatus()
        let shortcuts = buildShortcuts()
        let features = buildFeatures()
        let footer = label("在访达中右键即可使用；空白处右键时，操作当前目录。", size: 11, color: .secondaryLabelColor)
        let body = stack([heading, status, shortcuts, features, footer], spacing: 24)
        body.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(body)
        for view in body.arrangedSubviews {
            view.widthAnchor.constraint(equalTo: body.widthAnchor).isActive = true
        }
        NSLayoutConstraint.activate([
            sidebar.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            sidebar.topAnchor.constraint(equalTo: content.topAnchor),
            sidebar.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            sidebar.widthAnchor.constraint(equalToConstant: 218),
            body.leadingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: 30),
            body.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -30),
            body.topAnchor.constraint(equalTo: content.topAnchor, constant: 48),
            body.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -28)
        ])
        updateDirectoryLabel()
        updateExtensionStatus()
    }

    private func buildSidebar(in sidebar: NSView) {
        let mark = symbol("shippingbox.fill", size: 38, color: WindowColors.accent)
        let tile = panel(mark, fill: WindowColors.accent.withAlphaComponent(0.10), padding: 20)
        let description = NSTextField(wrappingLabelWithString: "让常用的文件操作，\n少一次寻找，\n多一点顺手。")
        description.font = .systemFont(ofSize: 13)
        description.textColor = .secondaryLabelColor
        let brand = stack([
            tile,
            label("右键小匣", size: 27, weight: .semibold),
            label("右键，少一步。", size: 14, weight: .medium, color: WindowColors.accent),
            description
        ], spacing: 16)
        brand.setCustomSpacing(24, after: tile)
        brand.setCustomSpacing(24, after: brand.arrangedSubviews[2])
        brand.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(brand)

        let safety = stack([
            symbol("checkmark.shield", size: 19, color: WindowColors.accent),
            label("安心，才够顺手", size: 12, weight: .medium),
            label("新建文件不覆盖已有内容", size: 11, color: .secondaryLabelColor),
            label("剪切时，原项目保持原位", size: 11, color: .secondaryLabelColor)
        ], spacing: 8)
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let about = stack([
            safety,
            label("原生轻量 · 无第三方依赖", size: 10, color: .secondaryLabelColor),
            label("版本 \(version)  /  macOS 13+", size: 10, color: .secondaryLabelColor)
        ], spacing: 8)
        about.setCustomSpacing(28, after: safety)
        about.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(about)
        NSLayoutConstraint.activate([
            brand.topAnchor.constraint(equalTo: sidebar.topAnchor, constant: 76),
            brand.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 26),
            brand.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -22),
            description.widthAnchor.constraint(equalTo: brand.widthAnchor),
            about.leadingAnchor.constraint(equalTo: brand.leadingAnchor),
            about.trailingAnchor.constraint(equalTo: brand.trailingAnchor),
            about.bottomAnchor.constraint(equalTo: sidebar.bottomAnchor, constant: -32),
            about.topAnchor.constraint(greaterThanOrEqualTo: brand.bottomAnchor, constant: 32)
        ])
    }

    private func buildExtensionStatus() -> NSView {
        extensionLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        extensionLabel.identifier = NSUserInterfaceItemIdentifier("extension-status")
        extensionHint.font = .systemFont(ofSize: 11)
        extensionHint.textColor = .secondaryLabelColor
        extensionIcon.translatesAutoresizingMaskIntoConstraints = false
        extensionIcon.widthAnchor.constraint(equalToConstant: 24).isActive = true
        extensionIcon.heightAnchor.constraint(equalToConstant: 24).isActive = true
        let text = stack([extensionLabel, extensionHint], spacing: 5)
        let manage = NSButton(title: "管理扩展…", target: self, action: #selector(manageExtension(_:)))
        manage.bezelStyle = .rounded
        manage.controlSize = .small
        manage.toolTip = "打开系统的 Finder 扩展管理界面"
        manage.setAccessibilityLabel("管理 Finder 扩展")
        manage.setContentCompressionResistancePriority(.required, for: .horizontal)
        let row = stack([extensionIcon, text, NSView(), manage], horizontal: true, spacing: 12)
        let card = panel(row, fill: WindowColors.accent.withAlphaComponent(0.06), padding: 16)
        card.heightAnchor.constraint(equalToConstant: 74).isActive = true
        return card
    }

    private func buildShortcuts() -> NSView {
        folderLabel.font = .systemFont(ofSize: 12, weight: .medium)
        folderLabel.lineBreakMode = .byTruncatingMiddle
        folderLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        pathLabel.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        pathLabel.textColor = .secondaryLabelColor
        pathLabel.isSelectable = true
        pathLabel.lineBreakMode = .byTruncatingMiddle
        pathLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        pathLabel.identifier = NSUserInterfaceItemIdentifier("selected-directory")
        let directoryText = stack([folderLabel, pathLabel], spacing: 4)
        for view in directoryText.arrangedSubviews {
            view.widthAnchor.constraint(equalTo: directoryText.widthAnchor).isActive = true
        }
        let choose = NSButton(title: "选择文件夹…", target: self, action: #selector(chooseFolder(_:)))
        choose.bezelStyle = .rounded
        choose.controlSize = .small
        choose.setContentCompressionResistancePriority(.required, for: .horizontal)
        choose.setContentHuggingPriority(.required, for: .horizontal)
        directoryText.setHuggingPriority(.defaultLow, for: .horizontal)
        let folder = stack([symbol("folder.fill", size: 23, color: WindowColors.accent), directoryText, choose],
                           horizontal: true, spacing: 12)
        let folderCard = panel(folder, fill: WindowColors.accent.withAlphaComponent(0.04), padding: 14)
        folderCard.heightAnchor.constraint(equalToConstant: 66).isActive = true

        let actions = stack([], horizontal: true, spacing: 10)
        actions.distribution = .fillEqually
        for (index, action) in MenuAction.allCases.enumerated() {
            let button: ShortcutButton
            switch action {
            case .terminal:
                button = ShortcutButton(title: "进入 iTerm", detail: "在此打开终端", symbol: "terminal", tint: WindowColors.accent)
            case .newText:
                button = ShortcutButton(title: "新建 TXT", detail: "写下一点想法", symbol: "doc.text", tint: .systemBlue)
            case .newMarkdown:
                button = ShortcutButton(title: "新建 Markdown", detail: "让灵感有格式", symbol: "text.badge.plus", tint: .systemOrange)
            case .toggleHiddenFiles, .goToFolder:
                continue
            }
            button.target = self
            button.action = #selector(runAction(_:))
            button.tag = index
            button.identifier = NSUserInterfaceItemIdentifier(action.rawValue)
            button.toolTip = "\(action.title)：在上方选择的文件夹中执行"
            actions.addArrangedSubview(button)
            button.heightAnchor.constraint(equalToConstant: 108).isActive = true
        }
        let section = stack([label("选个目录，试一试", size: 13, weight: .semibold), folderCard, actions], spacing: 12)
        folderCard.widthAnchor.constraint(equalTo: section.widthAnchor).isActive = true
        actions.widthAnchor.constraint(equalTo: section.widthAnchor).isActive = true
        return section
    }

    private func buildFeatures() -> NSView {
        let heading = stack([
            label("右键里，还有这些", size: 13, weight: .semibold), NSView(),
            label("在访达中使用", size: 10, color: .secondaryLabelColor)
        ], horizontal: true, spacing: 8)
        let first = stack([
            feature("复制绝对路径", detail: "多选项目，每行一个路径", symbol: "doc.on.clipboard"),
            feature("回到上级目录", detail: "打开父目录，定位原项目", symbol: "arrow.up.folder")
        ], horizontal: true, spacing: 16)
        let second = stack([
            feature("剪切", detail: "只记录路径，不立即移动", symbol: "scissors"),
            feature("粘贴（移动）", detail: "重名先检查，不覆盖文件", symbol: "tray.and.arrow.down")
        ], horizontal: true, spacing: 16)
        first.distribution = .fillEqually
        second.distribution = .fillEqually
        let grid = stack([first, second], spacing: 18)
        first.widthAnchor.constraint(equalTo: grid.widthAnchor).isActive = true
        second.widthAnchor.constraint(equalTo: grid.widthAnchor).isActive = true
        let card = panel(grid, padding: 18)
        let section = stack([heading, card], spacing: 12)
        heading.widthAnchor.constraint(equalTo: section.widthAnchor).isActive = true
        card.widthAnchor.constraint(equalTo: section.widthAnchor).isActive = true
        return section
    }

    private func feature(_ title: String, detail: String, symbol name: String) -> NSView {
        stack([
            symbol(name, size: 18, color: .secondaryLabelColor),
            stack([label(title, size: 12, weight: .medium), label(detail, size: 10, color: .secondaryLabelColor)], spacing: 5)
        ], horizontal: true, spacing: 12)
    }

    private func label(_ title: String, size: CGFloat, weight: NSFont.Weight = .regular,
                       color: NSColor = .labelColor) -> NSTextField {
        let view = NSTextField(labelWithString: title)
        view.font = .systemFont(ofSize: size, weight: weight)
        view.textColor = color
        view.setContentCompressionResistancePriority(.required, for: .vertical)
        return view
    }

    private func stack(_ views: [NSView], horizontal: Bool = false, spacing: CGFloat) -> NSStackView {
        let view = NSStackView(views: views)
        view.orientation = horizontal ? .horizontal : .vertical
        view.alignment = horizontal ? .centerY : .leading
        view.distribution = .fill
        view.spacing = spacing
        return view
    }

    private func symbol(_ name: String, size: CGFloat, color: NSColor) -> NSImageView {
        let image = NSImageView()
        image.image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: size, weight: .medium))
        image.contentTintColor = color
        image.translatesAutoresizingMaskIntoConstraints = false
        image.widthAnchor.constraint(equalToConstant: size + 2).isActive = true
        image.heightAnchor.constraint(equalToConstant: size + 2).isActive = true
        return image
    }

    private func panel(_ child: NSView, fill: NSColor = .controlBackgroundColor, padding: CGFloat) -> NSView {
        let view = SurfaceView(fill: fill, radius: 14)
        child.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(child)
        NSLayoutConstraint.activate([
            child.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: padding),
            child.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -padding),
            child.topAnchor.constraint(equalTo: view.topAnchor, constant: padding),
            child.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -padding)
        ])
        return view
    }

    @objc private func showWindow(_ sender: Any?) {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        updateExtensionStatus()
    }

    @objc private func chooseFolder(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.title = "选择操作文件夹"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = directory
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url, let self else { return }
            self.directory = url
            self.updateDirectoryLabel()
        }
    }

    @objc private func runAction(_ sender: NSButton) {
        do {
            try execute(ActionRequest(action: MenuAction.allCases[sender.tag], directory: directory))
        } catch {
            showError(error)
        }
    }

    @objc private func manageExtension(_ sender: Any?) {
        FIFinderSyncController.showExtensionManagementInterface()
    }

    private func execute(_ request: ActionRequest) throws {
        if request.action.requiresActiveFinder {
            try FinderShortcutService.perform(request.action)
            return
        }
        let folder = try DirectoryResolver.validate(request.directory)
        if request.action == .terminal {
            try TerminalService.open(in: folder)
        } else {
            guard let resources = Bundle.main.resourceURL else { throw MenuError.missingTemplate }
            let created = try TemplateCreator.create(request.action, in: folder,
                                                     templates: resources.appendingPathComponent("Templates"))
            NSWorkspace.shared.activateFileViewerSelecting([created])
        }
        directory = folder
        updateDirectoryLabel()
    }

    private func updateDirectoryLabel() {
        folderLabel.stringValue = directory.path == "/" ? "根目录" : directory.lastPathComponent
        folderLabel.toolTip = directory.path
        pathLabel.stringValue = directory.path
        pathLabel.toolTip = directory.path
        pathLabel.setAccessibilityValue(directory.path)
    }

    private func executeMove(_ request: MoveRequest) throws {
        let pasteboard = NSPasteboard.general
        let selection = try CutClipboard.require(request.selectionID, from: pasteboard)
        let moved: [URL]
        do {
            moved = try FileMover.move(selection.sources, to: request.directory)
        } catch let failure as FileMoveFailure {
            if CutClipboard.read(from: pasteboard)?.id == selection.id {
                try CutClipboard.write(CutSelection(sources: failure.remaining), to: pasteboard)
            }
            throw failure
        }
        CutClipboard.clear(selection.id, from: pasteboard)
        NSWorkspace.shared.activateFileViewerSelecting(moved)
        directory = request.directory
        updateDirectoryLabel()
    }

    private func updateExtensionStatus() {
        let enabled = FIFinderSyncController.isExtensionEnabled
        extensionLabel.stringValue = enabled ? "Finder 扩展已启用" : "再一步，开启右键小匣"
        extensionHint.stringValue = enabled ? "准备就绪，在访达中右键试试吧。" : "在系统设置中启用扩展，即可使用右键菜单。"
        extensionIcon.image = NSImage(systemSymbolName: enabled ? "checkmark.circle.fill" : "puzzlepiece.extension",
                                      accessibilityDescription: enabled ? "扩展已启用" : "扩展尚未启用")?
            .withSymbolConfiguration(.init(pointSize: 23, weight: .medium))
        extensionIcon.contentTintColor = enabled ? WindowColors.accent : .systemOrange
    }

    private func showError(_ error: Error) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert(error: error)
        alert.runModal()
    }
}

private enum WindowColors {
    static let accent = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(srgbRed: 0.48, green: 0.80, blue: 0.71, alpha: 1)
            : NSColor(srgbRed: 0.16, green: 0.42, blue: 0.35, alpha: 1)
    }
    static let sidebar = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(srgbRed: 0.12, green: 0.17, blue: 0.16, alpha: 1)
            : NSColor(srgbRed: 0.91, green: 0.95, blue: 0.92, alpha: 1)
    }
}

private final class SurfaceView: NSView {
    private let fill: NSColor
    private let radius: CGFloat

    init(fill: NSColor, radius: CGFloat) {
        self.fill = fill
        self.radius = radius
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { nil }

    override func draw(_ dirtyRect: NSRect) {
        fill.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius).fill()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}

private final class ShortcutButton: NSButton {
    private let detail: String
    private let symbol: String
    private let tint: NSColor
    private var isHovered = false
    private var hoverTracking: NSTrackingArea?

    init(title: String, detail: String, symbol: String, tint: NSColor) {
        self.detail = detail
        self.symbol = symbol
        self.tint = tint
        super.init(frame: .zero)
        self.title = title
        isBordered = false
        setButtonType(.momentaryPushIn)
        focusRingType = .exterior
        setAccessibilityLabel(title)
        setAccessibilityHelp(detail)
    }

    required init?(coder: NSCoder) { nil }

    override var intrinsicContentSize: NSSize { NSSize(width: 160, height: 108) }
    override var isFlipped: Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTracking { removeTrackingArea(hoverTracking) }
        let tracking = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
                                      owner: self, userInfo: nil)
        addTrackingArea(tracking)
        hoverTracking = tracking
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let outline = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 13, yRadius: 13)
        NSColor.controlBackgroundColor.setFill()
        outline.fill()
        if isHovered || isHighlighted {
            tint.withAlphaComponent(isHighlighted ? 0.16 : 0.07).setFill()
            outline.fill()
        }
        (isHovered ? tint.withAlphaComponent(0.5) : NSColor.separatorColor.withAlphaComponent(0.3)).setStroke()
        outline.lineWidth = 1
        outline.stroke()
        if window?.firstResponder === self, window?.isKeyWindow == true {
            NSColor.keyboardFocusIndicatorColor.setStroke()
            outline.lineWidth = 3
            outline.stroke()
        }

        tint.withAlphaComponent(0.10).setFill()
        NSBezierPath(roundedRect: NSRect(x: 14, y: 13, width: 32, height: 32), xRadius: 9, yRadius: 9).fill()
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 19, weight: .medium).applying(.init(paletteColors: [tint])))
        image?.draw(in: NSRect(x: 20, y: 19, width: 20, height: 20), from: .zero,
                    operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        let arrow = NSImage(systemSymbolName: "arrow.up.right", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 10, weight: .medium).applying(.init(paletteColors: [.secondaryLabelColor])))
        arrow?.draw(in: NSRect(x: bounds.width - 25, y: 16, width: 10, height: 10), from: .zero,
                    operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        (title as NSString).draw(at: NSPoint(x: 14, y: 55), withAttributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold), .foregroundColor: NSColor.labelColor
        ])
        (detail as NSString).draw(at: NSPoint(x: 14, y: 78), withAttributes: [
            .font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor
        ])
    }

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        needsDisplay = true
        return accepted
    }

    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        needsDisplay = true
        return resigned
    }

    override var focusRingMaskBounds: NSRect { bounds }

    override func drawFocusRingMask() {
        NSBezierPath(roundedRect: bounds, xRadius: 13, yRadius: 13).fill()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}
