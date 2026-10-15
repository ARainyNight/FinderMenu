import Foundation

enum DirectoryResolver {
    static func directory(for item: URL) throws -> URL {
        guard item.isFileURL else { throw MenuError.invalidDirectory }
        let values = try item.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
        let result = values.isDirectory == true && values.isPackage != true
            ? item : item.deletingLastPathComponent()
        return try validate(result)
    }

    static func validate(_ directory: URL) throws -> URL {
        guard directory.isFileURL else { throw MenuError.invalidDirectory }
        let normalized = directory.standardizedFileURL
        let values = try normalized.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
        guard values.isDirectory == true, values.isPackage != true else {
            throw MenuError.invalidDirectory
        }
        return normalized
    }
}
