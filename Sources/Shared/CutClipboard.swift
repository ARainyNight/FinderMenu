import AppKit

enum CutClipboard {
    static let type = NSPasteboard.PasteboardType("local.lindaoxiong.FinderMenu.cut-items")

    static func read(from pasteboard: NSPasteboard) -> CutSelection? {
        guard let data = pasteboard.data(forType: type) else { return nil }
        return try? JSONDecoder().decode(CutSelection.self, from: data)
    }

    static func write(_ selection: CutSelection, to pasteboard: NSPasteboard) throws {
        let data = try JSONEncoder().encode(selection)
        pasteboard.clearContents()
        guard pasteboard.setData(data, forType: type) else { throw MoveError.clipboardUnavailable }
    }

    static func require(_ id: UUID, from pasteboard: NSPasteboard) throws -> CutSelection {
        guard let selection = read(from: pasteboard), selection.id == id else {
            throw MoveError.staleClipboard
        }
        return selection
    }

    static func clear(_ id: UUID, from pasteboard: NSPasteboard) {
        if read(from: pasteboard)?.id == id {
            pasteboard.clearContents()
        }
    }
}
