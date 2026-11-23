import Foundation
import Testing
import UficastCore

/// Runs the guide's script exactly as the Shortcuts "Run Shell Script" action would (zsh, input on
/// stdin), with a stub `open` that records the link instead of opening it.
private func link(from script: String, stdin text: String) throws -> String? {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("uficast-guide-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let record = folder.appendingPathComponent("opened.txt")
    let stub = folder.appendingPathComponent("open")
    try "#!/bin/sh\nprintf '%s' \"$1\" > '\(record.path)'\n".write(to: stub, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: stub.path)

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/zsh")
    process.arguments = ["-c", script]
    process.environment = ["PATH": "\(folder.path):/usr/bin:/bin"]
    let input = Pipe()
    process.standardInput = input
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try process.run()
    input.fileHandleForWriting.write(Data(text.utf8))
    try input.fileHandleForWriting.close()
    process.waitUntilExit()
    #expect(process.terminationStatus == 0)
    return try? String(contentsOf: record, encoding: .utf8)
}

@Test func theScriptTurnsInputIntoALinkTheParserReadsBack() throws {
    let text = "we was here & +\nпривет #1 100% \"quoted\" 'single' $HOME `x`"
    for action in AITextAction.allCases {
        let opened = try #require(try link(from: ShortcutGuide.script(for: action), stdin: text))
        #expect(opened.hasPrefix(AITextURL.prefix(for: action)))
        #expect(!opened.contains(" ") && !opened.contains("\n") && !opened.contains("&"))
        let parsed = try #require(URL(string: opened).flatMap { AITextURL.parse($0) })
        #expect(parsed == AITextURL(action: action, text: text))
    }
}

@Test func theScriptKeepsTheTextExactlyAndOpensAnEmptyLinkForNoInput() throws {
    let opened = try #require(try link(from: ShortcutGuide.script(for: .translate), stdin: "line one\nline two\n"))
    #expect(URL(string: opened).flatMap { AITextURL.parse($0) }?.text == "line one\nline two\n")
    let empty = try #require(try link(from: ShortcutGuide.script(for: .rewrite), stdin: ""))
    #expect(empty == AITextURL.prefix(for: .rewrite))
    #expect(URL(string: empty).flatMap { AITextURL.parse($0) } == AITextURL(action: .rewrite, text: nil))
}

@Test func theGuideNamesTheShortcutAndListsTheStepsInOrder() {
    #expect(ShortcutGuide.shortcutName(for: .rewrite) == "Rewrite with Uficast")
    #expect(ShortcutGuide.shortcutName(for: .translate) == "Translate with Uficast")
    for action in AITextAction.allCases {
        let steps = ShortcutGuide.steps(for: action)
        #expect(steps.count == 5)
        #expect(steps[0].contains(ShortcutGuide.shortcutName(for: action)))
        #expect(steps[1].contains("Use as Quick Action") && steps[1].contains("Services Menu"))
        #expect(steps[2].contains("Text") && steps[2].contains("Get Clipboard"))
        #expect(steps[3].contains("Run Shell Script") && steps[3].contains("stdin"))
        #expect(steps[4].contains("Add Keyboard Shortcut"))
        // A plain combination such as ⌃⌘R was silently taken by another app on the owner's Mac.
        #expect(steps[4].contains("⌃⌘⇧R") && steps[4].contains("another app"))
    }
}
