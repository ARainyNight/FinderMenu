import AppKit
import Carbon.HIToolbox

@MainActor
enum FinderShortcutService {
    static func perform(_ action: MenuAction) throws {
        let (keyDown, keyUp) = try makeShortcut(for: action)
        let pid = try targetProcess(hasAccess: CGPreflightPostEventAccess(),
                                    application: NSWorkspace.shared.frontmostApplication)
        keyDown.postToPid(pid)
        keyUp.postToPid(pid)
    }

    static func targetProcess(hasAccess: Bool, application: NSRunningApplication?) throws -> pid_t {
        guard hasAccess else { throw FinderShortcutError.accessRequired }
        guard let application, application.bundleIdentifier == "com.apple.finder", !application.isTerminated else {
            throw FinderShortcutError.finderNotActive
        }
        return application.processIdentifier
    }

    static func makeShortcut(for action: MenuAction) throws -> (CGEvent, CGEvent) {
        let keyCode: CGKeyCode
        switch action {
        case .toggleHiddenFiles: keyCode = CGKeyCode(kVK_ANSI_Period)
        case .goToFolder: keyCode = CGKeyCode(kVK_ANSI_G)
        default: throw MenuError.invalidRequest
        }
        guard let source = CGEventSource(stateID: .privateState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            throw FinderShortcutError.eventUnavailable
        }
        keyDown.flags = [.maskCommand, .maskShift]
        keyUp.flags = [.maskCommand, .maskShift]
        return (keyDown, keyUp)
    }
}

enum FinderShortcutError: LocalizedError {
    case accessRequired
    case finderNotActive
    case eventUnavailable

    var errorDescription: String? {
        switch self {
        case .accessRequired:
            return "此操作需要控制权限。请在「系统设置 → 隐私与安全性 → 设备控制和数据访问」（旧版系统为「辅助功能」）中添加并开启「右键小匣」。授权后若仍提示权限不足，请退出并重新打开「右键小匣」，再回访达重试。"
        case .finderNotActive:
            return "请回到访达，在文件夹中右键重试此操作。"
        case .eventUnavailable:
            return "无法创建访达快捷键，请稍后重试。"
        }
    }
}
