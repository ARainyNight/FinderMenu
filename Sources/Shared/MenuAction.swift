import Foundation

enum MenuAction: String, CaseIterable {
    case terminal
    case newText
    case newMarkdown

    var title: String {
        switch self {
        case .terminal: return "进入终端"
        case .newText: return "新建 TXT 文件"
        case .newMarkdown: return "新建 Markdown 文件"
        }
    }

    var symbol: String {
        self == .terminal ? "terminal" : "doc.badge.plus"
    }

    var fileExtension: String? {
        switch self {
        case .terminal: return nil
        case .newText: return "txt"
        case .newMarkdown: return "md"
        }
    }
}

struct ActionRequest: Equatable {
    static let scheme = "findermenu-local"
    let action: MenuAction
    let directory: URL

    var url: URL {
        var components = URLComponents()
        components.scheme = Self.scheme
        components.host = "action"
        components.queryItems = [
            URLQueryItem(name: "type", value: action.rawValue),
            URLQueryItem(name: "directory", value: directory.path)
        ]
        return components.url!
    }

    init(action: MenuAction, directory: URL) {
        self.action = action
        self.directory = directory.standardizedFileURL
    }

    init(url: URL) throws {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == Self.scheme, components.host == "action",
              components.path.isEmpty, components.fragment == nil,
              components.user == nil, components.password == nil, components.port == nil,
              let items = components.queryItems, items.count == 2,
              items.filter({ $0.name == "type" }).count == 1,
              items.filter({ $0.name == "directory" }).count == 1,
              let rawAction = items.first(where: { $0.name == "type" })?.value,
              let action = MenuAction(rawValue: rawAction),
              let path = items.first(where: { $0.name == "directory" })?.value,
              path.hasPrefix("/"), !path.contains("\0") else {
            throw MenuError.invalidRequest
        }
        self.init(action: action, directory: URL(fileURLWithPath: path, isDirectory: true))
    }
}

enum MenuError: LocalizedError {
    case invalidRequest
    case invalidDirectory
    case missingTemplate
    case terminalUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidRequest: return "无法识别这次菜单操作。"
        case .invalidDirectory: return "目标文件夹不存在，或当前选择不是文件夹。"
        case .missingTemplate: return "文件模板缺失，请重新构建右键小匣。"
        case .terminalUnavailable: return "iTerm 服务调用失败。请确认已安装 iTerm，并在系统设置的键盘快捷键→服务→文件和文件夹中启用“New iTerm2 Window Here”，然后重试。"
        }
    }
}
