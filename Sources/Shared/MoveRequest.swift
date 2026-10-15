import Foundation

struct MoveRequest: Equatable {
    let selectionID: UUID
    let directory: URL

    var url: URL {
        var components = URLComponents()
        components.scheme = ActionRequest.scheme
        components.host = "move"
        components.queryItems = [
            URLQueryItem(name: "batch", value: selectionID.uuidString),
            URLQueryItem(name: "directory", value: directory.path)
        ]
        return components.url!
    }

    init(selectionID: UUID, directory: URL) {
        self.selectionID = selectionID
        self.directory = URL(fileURLWithPath: directory.path, isDirectory: true).standardizedFileURL
    }

    init(url: URL) throws {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == ActionRequest.scheme, components.host == "move",
              components.path.isEmpty, components.fragment == nil,
              components.user == nil, components.password == nil, components.port == nil,
              let items = components.queryItems, items.count == 2,
              items.filter({ $0.name == "batch" }).count == 1,
              items.filter({ $0.name == "directory" }).count == 1,
              let rawID = items.first(where: { $0.name == "batch" })?.value,
              let id = UUID(uuidString: rawID),
              let path = items.first(where: { $0.name == "directory" })?.value,
              path.hasPrefix("/"), !path.contains("\0") else {
            throw MenuError.invalidRequest
        }
        self.init(selectionID: id, directory: URL(fileURLWithPath: path, isDirectory: true))
    }
}
