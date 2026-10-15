import AppKit
import FinderSync
import OSLog

@objc(FinderMenuSync)
final class FinderMenuSync: FIFinderSync {
    private let logger = Logger(subsystem: "local.lindaoxiong.FinderMenu.Extension", category: "menu")
    private var requests: [Int: URL] = [:]
    private var pathsToCopy = ""
    private var itemToRevealInParent: URL?
    private var itemsToCut: [URL] = []
    private var moveRequestURL: URL?

    override init() {
        super.init()
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/", isDirectory: true)]
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        let controller = FIFinderSyncController.default()
        let directory: URL
        let copyTargets: [URL]
        do {
            switch menuKind {
            case .contextualMenuForContainer:
                guard let target = controller.targetedURL() else { return nil }
                copyTargets = [target]
                directory = try DirectoryResolver.validate(target)
            case .contextualMenuForItems, .contextualMenuForSidebar:
                let items = controller.selectedItemURLs() ?? []
                guard let target = items.first ?? controller.targetedURL() else { return nil }
                copyTargets = items.isEmpty ? [target] : items
                if items.count > 1 {
                    let parents = Set(items.map { $0.deletingLastPathComponent().standardizedFileURL })
                    guard parents.count == 1, let parent = parents.first else { return nil }
                    directory = try DirectoryResolver.validate(parent)
                } else {
                    directory = try DirectoryResolver.directory(for: target)
                }
            default:
                return nil
            }
        } catch {
            logger.error("Cannot resolve menu directory: \(error.localizedDescription, privacy: .public)")
            return nil
        }

        let menu = NSMenu(title: "右键小匣")
        let newFileMenu = NSMenu(title: "新建文件")
        requests.removeAll()
        for (index, action) in MenuAction.allCases.enumerated() {
            let item = NSMenuItem(title: action.title, action: #selector(performAction(_:)), keyEquivalent: "")
            item.target = self
            item.image = NSImage(systemSymbolName: action.symbol, accessibilityDescription: action.title)
            item.tag = index + 1
            requests[item.tag] = ActionRequest(action: action, directory: directory).url
            if action == .terminal {
                menu.addItem(item)
            } else {
                newFileMenu.addItem(item)
            }
        }
        let newFileItem = NSMenuItem(title: "新建文件", action: nil, keyEquivalent: "")
        newFileItem.image = NSImage(systemSymbolName: "doc.badge.plus", accessibilityDescription: "新建文件")
        newFileItem.submenu = newFileMenu
        menu.addItem(newFileItem)
        pathsToCopy = copyTargets.map(\.path).joined(separator: "\n")
        let copyPathItem = NSMenuItem(title: "复制绝对路径", action: #selector(copyAbsolutePath(_:)), keyEquivalent: "")
        copyPathItem.target = self
        copyPathItem.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "复制绝对路径")
        menu.addItem(copyPathItem)
        let target = copyTargets[0]
        itemToRevealInParent = target.path == "/" ? nil : target
        if itemToRevealInParent != nil {
            let goUpItem = NSMenuItem(title: "回到上级目录", action: #selector(goToParentDirectory(_:)), keyEquivalent: "")
            goUpItem.target = self
            goUpItem.image = NSImage(systemSymbolName: "arrow.up.folder", accessibilityDescription: "回到上级目录")
            menu.addItem(goUpItem)
        }
        itemsToCut = menuKind == .contextualMenuForItems && !copyTargets.contains(where: { $0.path == "/" })
            ? copyTargets : []
        if !itemsToCut.isEmpty {
            let cutItem = NSMenuItem(title: "剪切", action: #selector(cutItems(_:)), keyEquivalent: "")
            cutItem.target = self
            cutItem.image = NSImage(systemSymbolName: "scissors", accessibilityDescription: "剪切")
            menu.addItem(cutItem)
        }
        moveRequestURL = nil
        let isDestination = menuKind == .contextualMenuForContainer
            || (copyTargets.count == 1 && (try? DirectoryResolver.validate(target)) != nil)
        if isDestination, let selection = CutClipboard.read(from: .general) {
            moveRequestURL = MoveRequest(selectionID: selection.id, directory: directory).url
            let pasteItem = NSMenuItem(title: "粘贴（移动）", action: #selector(pasteMovedItems(_:)), keyEquivalent: "")
            pasteItem.target = self
            pasteItem.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "粘贴（移动）")
            menu.addItem(pasteItem)
        }
        return menu
    }

    @objc private func cutItems(_ sender: NSMenuItem) {
        do {
            try CutClipboard.write(CutSelection(sources: itemsToCut), to: .general)
        } catch {
            logger.error("Cannot cut selected items: \(error.localizedDescription, privacy: .public)")
        }
    }

    @objc private func pasteMovedItems(_ sender: NSMenuItem) {
        guard let url = moveRequestURL else { return }
        if !NSWorkspace.shared.open(url) {
            logger.error("FinderMenu could not open the move URL. Open the containing app first.")
        }
    }

    @objc private func goToParentDirectory(_ sender: NSMenuItem) {
        guard let item = itemToRevealInParent else { return }
        NSWorkspace.shared.activateFileViewerSelecting([item])
    }

    @objc private func copyAbsolutePath(_ sender: NSMenuItem) {
        guard !pathsToCopy.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if !pasteboard.setString(pathsToCopy, forType: .string) {
            logger.error("FinderMenu could not copy absolute paths to the clipboard.")
        }
    }

    @objc private func performAction(_ sender: NSMenuItem) {
        guard let url = requests[sender.tag] else {
            logger.error("No request for Finder menu tag \(sender.tag)")
            return
        }
        if !NSWorkspace.shared.open(url) {
            logger.error("FinderMenu could not open the action URL. Open the containing app first.")
        }
    }
}
