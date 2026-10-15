import Foundation

struct FileMoveFailure: LocalizedError {
    let moved: [URL]
    let remaining: [URL]
    let cause: Error

    var errorDescription: String? {
        "已移动 \(moved.count) 项，剩余 \(remaining.count) 项未完成。\n\(cause.localizedDescription)"
    }
}

enum FileMover {
    static func move(_ sources: [URL], to directory: URL,
                     manager: FileManager = .default) throws -> [URL] {
        let selection = try CutSelection(sources: sources)
        let folder = try DirectoryResolver.validate(directory)
        let physicalFolder = folder.resolvingSymlinksInPath()
        var destinations: [URL] = []
        var names = Set<String>()
        for source in selection.sources {
            let attributes = try manager.attributesOfItem(atPath: source.path)
            let physicalSource = source.deletingLastPathComponent().resolvingSymlinksInPath()
                .appendingPathComponent(source.lastPathComponent)
            guard physicalFolder.path != physicalSource.deletingLastPathComponent().path else {
                throw MoveError.invalidDestination
            }
            if attributes[.type] as? FileAttributeType == .typeDirectory,
               physicalFolder.path == physicalSource.path || physicalFolder.path.hasPrefix(physicalSource.path + "/") {
                throw MoveError.invalidDestination
            }
            let destination = folder.appendingPathComponent(source.lastPathComponent)
            guard names.insert(source.lastPathComponent).inserted,
                  (try? manager.attributesOfItem(atPath: destination.path)) == nil else {
                throw MoveError.collision(source.lastPathComponent)
            }
            destinations.append(destination)
        }

        var moved: [URL] = []
        for (index, source) in selection.sources.enumerated() {
            do {
                try manager.moveItem(at: source, to: destinations[index])
                moved.append(destinations[index])
            } catch {
                throw FileMoveFailure(moved: moved, remaining: Array(selection.sources[index...]), cause: error)
            }
        }
        return moved
    }
}
