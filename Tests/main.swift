import Foundation
import AppKit

let project = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let fixtures = project.appendingPathComponent("work/verification-\(UUID().uuidString)", isDirectory: true)
let directory = fixtures.appendingPathComponent("中文 空格 &#+%' 文件夹", isDirectory: true)
let templates = project.appendingPathComponent("Resources/Templates", isDirectory: true)
let manager = FileManager.default
try manager.createDirectory(at: directory, withIntermediateDirectories: true)

var checks = 0
@MainActor
func expect(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
    guard try condition() else { fatalError("FAIL: \(message)") }
    checks += 1
    print("PASS: \(message)")
}

@MainActor
func expectFailure(_ message: String, _ operation: () throws -> Void) {
    do {
        try operation()
        fatalError("FAIL: \(message)")
    } catch {
        checks += 1
        print("PASS: \(message)")
    }
}

for action in MenuAction.allCases {
    let request = ActionRequest(action: action, directory: directory)
    try expect(try ActionRequest(url: request.url) == request, "URL round trip: \(action.rawValue), Unicode and reserved characters")
}

let invalidRequests = [
    "https://action?type=newText&directory=/tmp",
    "findermenu-local://other?type=newText&directory=/tmp",
    "findermenu-local://action?type=delete&directory=/tmp",
    "findermenu-local://action?type=newText&directory=relative",
    "findermenu-local://action?type=newText&directory=/tmp&type=terminal",
    "findermenu-local://action?type=newText&directory=/tmp&extra=1",
    "findermenu-local://action?type=newText&directory=/tmp%00bad",
    "findermenu-local://action/path?type=newText&directory=/tmp",
    "findermenu-local://action?type=newText&directory=/tmp#fragment",
    "findermenu-local://action?type=newText"
]
for value in invalidRequests {
    expectFailure("Reject malformed request: \(value)") {
        _ = try ActionRequest(url: URL(string: value)!)
    }
}

let existing = directory.appendingPathComponent("新建文件.txt")
let original = Data("保留已有内容".utf8)
try original.write(to: existing, options: .withoutOverwriting)
let created = try TemplateCreator.create(.newText, in: directory, templates: templates)
try expect(created.lastPathComponent == "新建文件 2.txt", "Name collision receives a new number")
try expect(try Data(contentsOf: existing) == original, "Existing file content is preserved")
try expect(try Data(contentsOf: created).isEmpty, "TXT template creates an empty file")
let markdown = try TemplateCreator.create(.newMarkdown, in: directory, templates: templates)
try expect(markdown.lastPathComponent == "新建文件.md", "Markdown uses its own extension")
try expect(try Data(contentsOf: markdown).isEmpty, "Markdown template creates an empty file")

try expect(try DirectoryResolver.directory(for: created) == directory.standardizedFileURL, "A selected file resolves to its parent")
try expect(try DirectoryResolver.directory(for: directory) == directory.standardizedFileURL, "A selected folder resolves to itself")
let appBundle = project.appendingPathComponent("build/FinderMenu.app")
try expect(try DirectoryResolver.directory(for: appBundle) == appBundle.deletingLastPathComponent(), "Application packages resolve to their parent")
try expect(Bundle(url: appBundle)?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String == "右键小匣",
           "App bundle displays the Chinese product name")
let extensionBundle = appBundle.appendingPathComponent("Contents/PlugIns/FinderMenuExtension.appex")
try expect(Bundle(url: extensionBundle)?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String == "右键小匣",
           "Finder extension displays the same Chinese product name")
for url in [appBundle, extensionBundle] {
    let bundle = Bundle(url: url)!
    let label = url.pathExtension
    try expect(bundle.infoDictionary?["CFBundleDisplayName"] as? String == url.deletingPathExtension().lastPathComponent,
               "\(label): base display name matches the filesystem name for Finder localization")
    try expect(bundle.localizedInfoDictionary?["CFBundleName"] as? String == "右键小匣"
               && bundle.localizedInfoDictionary?["CFBundleDisplayName"] as? String == "右键小匣",
               "\(label): both localized bundle names contain the product name")
    let filesystemDisplayName = label == "appex" ? "右键小匣.appex" : "右键小匣"
    try expect(manager.displayName(atPath: url.path) == filesystemDisplayName,
               "\(label): FileManager displays the Chinese name rather than the filename")
    try expect(try url.resourceValues(forKeys: [.localizedNameKey]).localizedName == filesystemDisplayName,
               "\(label): URL resource metadata displays the Chinese name")
    try expect(bundle.object(forInfoDictionaryKey: "CFBundleIconFile") as? String == "AppIcon.icns",
               "\(label): declares the packaged application icon")
    let iconURL = bundle.resourceURL!.appendingPathComponent("AppIcon.icns")
    let icon = NSImage(contentsOf: iconURL)
    try expect(icon?.isValid == true, "\(label): packaged icon can be decoded by AppKit")
    let sizes = Set(icon!.representations.map(\.pixelsWide))
    try expect(Set([16, 32, 64, 128, 256, 512, 1024]).isSubset(of: sizes),
               "\(label): icon includes standard and Retina sizes through 1024 pixels")
    try expect(try Data(contentsOf: iconURL) == Data(contentsOf: project.appendingPathComponent("work/AppIcon.icns")),
               "\(label): packaged icon matches the generated artwork")
}
expectFailure("Reject a file as a creation directory") {
    _ = try TemplateCreator.create(.newText, in: existing, templates: templates)
}
expectFailure("Reject a missing directory") {
    _ = try TemplateCreator.create(.newText, in: fixtures.appendingPathComponent("missing"), templates: templates)
}
expectFailure("Report missing templates") {
    _ = try TemplateCreator.create(.newText, in: directory, templates: fixtures.appendingPathComponent("missing-templates"))
}
expectFailure("Terminal cannot be treated as a file type") {
    _ = try TemplateCreator.create(.terminal, in: directory, templates: templates)
}

let blockedFolder = directory.appendingPathComponent("新建文件 3.txt", isDirectory: true)
try manager.createDirectory(at: blockedFolder, withIntermediateDirectories: false)
let link = directory.appendingPathComponent("新建文件 4.txt")
try manager.createSymbolicLink(at: link, withDestinationURL: directory.appendingPathComponent("absent"))
let afterBlocked = try TemplateCreator.create(.newText, in: directory, templates: templates)
try expect(afterBlocked.lastPathComponent == "新建文件 5.txt", "Existing directories and dangling links are not overwritten")
try expect(try manager.destinationOfSymbolicLink(atPath: link.path) == directory.appendingPathComponent("absent").path,
           "Dangling link remains intact")

final class ConcurrentResults: @unchecked Sendable {
    private let lock = NSLock()
    private var urls: [URL] = []
    private var failures: [String] = []

    func record(_ result: Result<URL, Error>) {
        lock.lock()
        defer { lock.unlock() }
        switch result {
        case .success(let url): urls.append(url)
        case .failure(let error): failures.append(error.localizedDescription)
        }
    }

    func snapshot() -> ([URL], [String]) {
        lock.lock()
        defer { lock.unlock() }
        return (urls, failures)
    }
}

let results = ConcurrentResults()
DispatchQueue.concurrentPerform(iterations: 12) { _ in
    results.record(Result { try TemplateCreator.create(.newMarkdown, in: directory, templates: templates) })
}
let (urls, errors) = results.snapshot()
try expect(errors.isEmpty, "Concurrent creation reports no errors: \(errors)")
try expect(urls.count == 12 && Set(urls).count == 12, "Concurrent requests each receive a unique file")
try expect(try Data(contentsOf: existing) == original, "Concurrent creation preserves original content")
let moveRoot = fixtures.appendingPathComponent("move-checks")
let moveSource = moveRoot.appendingPathComponent("source")
let moveTarget = moveRoot.appendingPathComponent("target 中文 &#+%'")
try manager.createDirectory(at: moveSource, withIntermediateDirectories: true)
try manager.createDirectory(at: moveTarget, withIntermediateDirectories: true)
let moveFile = moveSource.appendingPathComponent("文件 &#+%'.txt")
let moveFolder = moveSource.appendingPathComponent("folder")
try original.write(to: moveFile, options: .withoutOverwriting)
try manager.createDirectory(at: moveFolder, withIntermediateDirectories: false)
try original.write(to: moveFolder.appendingPathComponent(".hidden"), options: .withoutOverwriting)
let selection = try CutSelection(sources: [moveFile, moveFolder])
try expect(try JSONDecoder().decode(CutSelection.self, from: JSONEncoder().encode(selection)) == selection,
           "Cut selection preserves multiple Unicode paths")
for invalidSources in [[], [moveFile, moveFile], [URL(fileURLWithPath: "/")],
                       [URL(fileURLWithPath: "/tmp/..")], [URL(string: "https://example.com/file")!]] {
    expectFailure("Reject invalid cut selection") { _ = try CutSelection(sources: invalidSources) }
}
let badSelection = try JSONSerialization.data(withJSONObject: ["id": UUID().uuidString, "paths": ["relative"]])
expectFailure("Reject malformed clipboard selection") {
    _ = try JSONDecoder().decode(CutSelection.self, from: badSelection)
}
let moveRequest = MoveRequest(selectionID: selection.id, directory: moveTarget)
try expect(try MoveRequest(url: moveRequest.url) == moveRequest, "Move request preserves batch ID and special path")
for value in [
    "findermenu-local://move?batch=bad&directory=/tmp",
    "findermenu-local://move?batch=\(selection.id)&directory=relative",
    "findermenu-local://move?batch=\(selection.id)&directory=/tmp%00bad",
    moveRequest.url.absoluteString + "&batch=\(selection.id)",
    moveRequest.url.absoluteString + "#fragment",
    moveRequest.url.absoluteString.replacingOccurrences(of: "findermenu-local:", with: "https:")
] {
    expectFailure("Reject malformed move request") { _ = try MoveRequest(url: URL(string: value)!) }
}
let pasteboard = NSPasteboard.withUniqueName()
try CutClipboard.write(selection, to: pasteboard)
try expect(try CutClipboard.require(selection.id, from: pasteboard) == selection, "Private clipboard stores cut paths")
try expect(manager.fileExists(atPath: moveFile.path) && manager.fileExists(atPath: moveFolder.path),
           "Cut does not move source items")
expectFailure("Reject stale paste menu") { _ = try CutClipboard.require(UUID(), from: pasteboard) }
CutClipboard.clear(UUID(), from: pasteboard)
try expect(CutClipboard.read(from: pasteboard) == selection, "Old completion cannot clear a newer clipboard record")
pasteboard.clearContents()
pasteboard.setString("copied content", forType: .string)
try expect(CutClipboard.read(from: pasteboard) == nil, "Copying other content cancels cut")
try CutClipboard.write(selection, to: pasteboard)
CutClipboard.clear(selection.id, from: pasteboard)
try expect(CutClipboard.read(from: pasteboard) == nil, "Successful completion clears cut record")
let moved = try FileMover.move(selection.sources, to: moveTarget)
try expect(moved.count == 2 && !manager.fileExists(atPath: moveFile.path)
           && !manager.fileExists(atPath: moveFolder.path), "Move transfers a file and folder together")
try expect(try Data(contentsOf: moved[0]) == original, "Moved file content is preserved")
try expect(try Data(contentsOf: moved[1].appendingPathComponent(".hidden")) == original,
           "Moved folder retains hidden file content")

let freeFile = moveSource.appendingPathComponent("free.txt")
let conflicting = moveSource.appendingPathComponent(moveFile.lastPathComponent)
try original.write(to: freeFile, options: .withoutOverwriting)
try Data("source".utf8).write(to: conflicting, options: .withoutOverwriting)
expectFailure("Preflight collision stops the entire batch") {
    _ = try FileMover.move([freeFile, conflicting], to: moveTarget)
}
try expect(manager.fileExists(atPath: freeFile.path) && !manager.fileExists(atPath: moveTarget.appendingPathComponent("free.txt").path),
           "A free first item stays in place when a later item conflicts")
try expect(try Data(contentsOf: moved[0]) == original, "Collision preserves destination content")
let danglingDestination = moveTarget.appendingPathComponent("free.txt")
try manager.createSymbolicLink(at: danglingDestination, withDestinationURL: moveRoot.appendingPathComponent("absent"))
expectFailure("Dangling destination link prevents overwrite") { _ = try FileMover.move([freeFile], to: moveTarget) }
try expect(try manager.destinationOfSymbolicLink(atPath: danglingDestination.path) == moveRoot.appendingPathComponent("absent").path,
           "Dangling destination link stays intact")
expectFailure("Missing later source prevents moving earlier source") {
    _ = try FileMover.move([conflicting, moveSource.appendingPathComponent("missing")], to: moveRoot)
}
try expect(manager.fileExists(atPath: conflicting.path), "Preflight missing source leaves batch intact")
expectFailure("Reject moving to the same directory") { _ = try FileMover.move([freeFile], to: moveSource) }
expectFailure("Reject moving folder into itself") { _ = try FileMover.move([moveSource], to: moveSource) }
let child = moveSource.appendingPathComponent("child")
try manager.createDirectory(at: child, withIntermediateDirectories: false)
expectFailure("Reject moving folder into its child") { _ = try FileMover.move([moveSource], to: child) }
let childAlias = moveRoot.appendingPathComponent("child-alias")
try manager.createSymbolicLink(at: childAlias, withDestinationURL: child)
expectFailure("Reject moving folder through a symlink into its child") { _ = try FileMover.move([moveSource], to: childAlias) }
expectFailure("Reject empty move batch") { _ = try FileMover.move([], to: moveTarget) }
expectFailure("Reject duplicate destination names before moving") {
    _ = try FileMover.move([conflicting, moved[0]], to: moveRoot)
}
let sourceLink = moveSource.appendingPathComponent("source-link")
try manager.createSymbolicLink(at: sourceLink, withDestinationURL: conflicting)
let movedLink = try FileMover.move([sourceLink], to: moveTarget)[0]
try expect(try manager.destinationOfSymbolicLink(atPath: movedLink.path) == conflicting.path,
           "Move transfers the symlink itself")
try expect(manager.fileExists(atPath: conflicting.path), "Moving a link preserves the original target")

final class FailingMoveManager: FileManager {
    override func moveItem(at srcURL: URL, to dstURL: URL) throws {
        if srcURL.lastPathComponent == "fail.txt" { throw CocoaError(.fileWriteNoPermission) }
        try super.moveItem(at: srcURL, to: dstURL)
    }
}
let partialSource = moveRoot.appendingPathComponent("partial-source")
let partialTarget = moveRoot.appendingPathComponent("partial-target")
try manager.createDirectory(at: partialSource, withIntermediateDirectories: false)
try manager.createDirectory(at: partialTarget, withIntermediateDirectories: false)
let partialFiles = ["first.txt", "fail.txt", "last.txt"].map { partialSource.appendingPathComponent($0) }
for file in partialFiles { try original.write(to: file, options: .withoutOverwriting) }
do {
    _ = try FileMover.move(partialFiles, to: partialTarget, manager: FailingMoveManager())
    fatalError("FAIL: Expected partial failure")
} catch let failure as FileMoveFailure {
    try expect(failure.moved == [partialTarget.appendingPathComponent("first.txt")]
               && failure.remaining == Array(partialFiles[1...]), "Partial failure reports completed and remaining paths")
    try CutClipboard.write(CutSelection(sources: failure.remaining), to: pasteboard)
    try expect(CutClipboard.read(from: pasteboard)?.sources == Array(partialFiles[1...]),
               "Partial failure can retain only remaining paths for retry")
    try expect(!manager.fileExists(atPath: partialFiles[0].path)
               && manager.fileExists(atPath: partialFiles[1].path) && manager.fileExists(atPath: partialFiles[2].path),
               "Partial failure does not repeat or lose completed items")
    _ = try FileMover.move(failure.remaining, to: partialTarget)
    try expect(try partialFiles.allSatisfy { try Data(contentsOf: partialTarget.appendingPathComponent($0.lastPathComponent)) == original },
               "Retry moves remaining items and preserves all content")
}
print("\(checks) checks passed. Fixtures retained at: \(fixtures.path)")
