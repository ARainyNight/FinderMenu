import AppKit
import Carbon.HIToolbox

@MainActor
enum HiddenFilesService {
    static func toggle() throws {
        let pid = try targetProcess(hasAccess: CGPreflightPostEventAccess(),
                                    application: NSWorkspace.shared.frontmostApplication)
        let (keyDown, keyUp) = try makeShortcut()
        keyDown.postToPid(pid)
        keyUp.postToPid(pid)
    }

    static func targetProcess(hasAccess: Bool, application: NSRunningApplication?) throws -> pid_t {
        guard hasAccess else { throw HiddenFilesError.accessRequired }
        guard let application, application.bundleIdentifier == "com.apple.finder", !application.isTerminated else {
            throw HiddenFilesError.finderNotActive
        }
        return application.processIdentifier
    }

    static func makeShortcut() throws -> (CGEvent, CGEvent) {
        guard let source = CGEventSource(stateID: .privateState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_Period), keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_Period), keyDown: false) else {
            throw HiddenFilesError.eventUnavailable
        }
        keyDown.flags = [.maskCommand, .maskShift]
        keyUp.flags = [.maskCommand, .maskShift]
        return (keyDown, keyUp)
    }
}

enum HiddenFilesError: LocalizedError {
    case accessRequired
    case finderNotActive
    case eventUnavailable

    var errorDescription: String? {
        switch self {
        case .accessRequired:
            return "显示／隐藏隐藏文件需要控制权限。请在「系统设置 → 隐私与安全性 → 设备控制和数据访问」（旧版系统为「辅助功能」）中添加并开启「右键小匣」。授权后若仍提示权限不足，请退出并重新打开「右键小匣」，再回访达重试。"
        case .finderNotActive:
            return "请回到访达，在文件夹中右键选择“显示／隐藏隐藏文件”。"
        case .eventUnavailable:
            return "无法创建隐藏文件切换快捷键，请稍后重试。"
        }
    }
}
