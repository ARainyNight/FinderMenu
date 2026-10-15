import Foundation

enum TemplateCreator {
    static func create(_ action: MenuAction, in directory: URL, templates: URL) throws -> URL {
        guard let suffix = action.fileExtension else { throw MenuError.invalidRequest }
        let folder = try DirectoryResolver.validate(directory)
        let source = templates.appendingPathComponent("Empty.\(suffix)")
        guard FileManager.default.fileExists(atPath: source.path) else {
            throw MenuError.missingTemplate
        }

        var number = 1
        while true {
            let name = number == 1 ? "新建文件.\(suffix)" : "新建文件 \(number).\(suffix)"
            let destination = folder.appendingPathComponent(name)
            do {
                try FileManager.default.copyItem(at: source, to: destination)
                return destination
            } catch let error as NSError {
                guard error.domain == NSCocoaErrorDomain,
                      error.code == CocoaError.fileWriteFileExists.rawValue else { throw error }
                number += 1
            }
        }
    }
}
