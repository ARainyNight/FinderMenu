import Foundation

struct CutSelection: Codable, Equatable {
    let id: UUID
    let paths: [String]

    var sources: [URL] { paths.map { URL(fileURLWithPath: $0) } }

    init(sources: [URL], id: UUID = UUID()) throws {
        guard sources.allSatisfy({ $0.isFileURL }) else { throw MoveError.invalidSelection }
        try self.init(id: id, paths: sources.map(\.path))
    }

    private init(id: UUID, paths: [String]) throws {
        let normalized = paths.map { URL(fileURLWithPath: $0).standardizedFileURL.path }
        guard !paths.isEmpty, Set(normalized).count == paths.count,
              paths.allSatisfy({ $0.hasPrefix("/") && !$0.contains("\0")
                  && !$0.split(separator: "/").contains(where: { $0 == "." || $0 == ".." }) }),
              !normalized.contains("/") else {
            throw MoveError.invalidSelection
        }
        self.id = id
        self.paths = normalized
    }

    private enum CodingKeys: String, CodingKey { case id, paths }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(id: values.decode(UUID.self, forKey: .id),
                      paths: values.decode([String].self, forKey: .paths))
    }
}

enum MoveError: LocalizedError {
    case invalidSelection
    case staleClipboard
    case clipboardUnavailable
    case collision(String)
    case invalidDestination

    var errorDescription: String? {
        switch self {
        case .invalidSelection: return "待移动项目无效，请重新选择文件或文件夹并剪切。"
        case .staleClipboard: return "剪贴板已改变，请重新剪切后再粘贴（移动）。"
        case .clipboardUnavailable: return "无法记录待移动路径，请重新剪切。"
        case .collision(let name): return "目标目录已存在同名项目「\(name)」，本次未移动任何项目。"
        case .invalidDestination: return "不能移动到原目录、目录自身或其子目录，请选择其他目标目录。"
        }
    }
}
