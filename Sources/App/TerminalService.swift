import AppKit

@MainActor
enum TerminalService {
    static func open(in directory: URL) throws {
        let folder = try DirectoryResolver.validate(directory)
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let filenames = NSPasteboard.PasteboardType("NSFilenamesPboardType")
        pasteboard.declareTypes([filenames], owner: nil)
        pasteboard.setPropertyList([folder.path], forType: filenames)
        guard NSPerformService("New iTerm2 Window Here", pasteboard) else {
            throw MenuError.terminalUnavailable
        }
    }
}
