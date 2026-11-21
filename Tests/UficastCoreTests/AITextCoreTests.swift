import Foundation
import Testing
import UficastCore

private let controlOptionR = GlobalShortcut(keyCode: 15, modifiers: GlobalShortcut.control | GlobalShortcut.option, keyLabel: "R")

private func temporaryDirectory() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("uficast-ai-\(UUID().uuidString)")
}

@Test func legacyConfigGetsDefaultAIText() throws {
    let legacy = Data(#"{"schemaVersion":1,"applicationRoots":[],"applications":{},"scripts":[]}"#.utf8)
    let config = try Configuration.decode(legacy)
    #expect(config.aiText.command == AITextPreferences.defaultCommand)
    #expect(config.aiText.rewriteHotkey == nil)
    #expect(config.aiText.translateHotkey == nil)
}

@Test func aiCommandValidation() throws {
    var config = Configuration()
    for invalid in ["   ", "claude\0-p", String(repeating: "a", count: 2001)] {
        config.aiText.command = invalid
        #expect(throws: ConfigError.self) { try config.validated() }
    }
    config.aiText.command = String(repeating: "a", count: 2000)
    _ = try config.validated()
}

@Test func aiHotkeysConflictWithLauncherAppsAndEachOther() throws {
    var config = Configuration()
    config.aiText.rewriteHotkey = .launcher
    #expect(throws: ConfigError.self) { try config.validated() }
    config.aiText.rewriteHotkey = controlOptionR
    config.aiText.translateHotkey = controlOptionR
    #expect(throws: ConfigError.self) { try config.validated() }
    config.aiText.translateHotkey = nil
    config.applications["app:fixture"] = AppOverride(hotkey: controlOptionR)
    #expect(throws: ConfigError.self) { try config.validated() }
    config.applications["app:fixture"]?.isEnabled = false
    _ = try config.validated()
}

@Test func aiHotkeysRoundTrip() throws {
    var config = Configuration()
    config.aiText.command = "claude -p --model claude-sonnet-5-5"
    config.aiText.rewriteHotkey = controlOptionR
    config.aiText.translateHotkey = GlobalShortcut(keyCode: 17, modifiers: GlobalShortcut.control | GlobalShortcut.option, keyLabel: "T")
    #expect(try Configuration.decode(config.encoded()) == config)
}

@Test func promptCarriesInstructionsAndText() {
    let rewrite = AITextPrompt.build(action: .rewrite, text: "we was here", hasMarkers: false)
    #expect(rewrite.contains("<text>\nwe was here\n</text>"))
    #expect(rewrite.contains("simple English"))
    #expect(!rewrite.contains("<s1>"))
    let translate = AITextPrompt.build(action: .translate, text: "Привет <s1>мир</s1>", hasMarkers: true)
    #expect(translate.contains("Russian"))
    #expect(translate.contains("English"))
    #expect(translate.contains("<s1>"))
}

@Test func translateNamesTheDirectionExplicitly() {
    let toEnglish = AITextPrompt.build(action: .translate, text: "Привет <s1>всем</s1>, это тест API", hasMarkers: true)
    #expect(toEnglish.contains("from Russian into English"))
    let toRussian = AITextPrompt.build(action: .translate, text: "<s1>Hello</s1> world &lt;b&gt;", hasMarkers: true)
    #expect(toRussian.contains("from English into Russian"))
    #expect(toRussian.contains("must be written in Russian"))
    #expect(!AITextPrompt.isMainlyRussian("<s12>abc</s12> 123"))
    #expect(AITextPrompt.isMainlyRussian("ёЙ"))
}

@Test func cleanStripsEchoedTagsAndWhitespace() {
    #expect(AITextPrompt.clean("\n<text>\nHello\n</text>\n") == "Hello")
    #expect(AITextPrompt.clean("  Hi there \n") == "Hi there")
    #expect(AITextPrompt.clean("<text>only open") == "<text>only open")
}

@Test func runnerReturnsStdoutTrimmed() async throws {
    let runner = AITextRunner(workingDirectory: temporaryDirectory())
    #expect(try await runner.run(command: "cat", prompt: "Hello\n", timeout: 5) == "Hello")
}

@Test func runnerReportsMissingCLIWithStderr() async throws {
    let runner = AITextRunner(workingDirectory: temporaryDirectory())
    do {
        _ = try await runner.run(command: "uficast-no-such-cli-xyz", prompt: "x", timeout: 5)
        Issue.record("A missing CLI produced a result")
    } catch let AITextError.failed(message) {
        #expect(message.contains("not found"))
    }
}

@Test func runnerRejectsEmptyOutput() async throws {
    let runner = AITextRunner(workingDirectory: temporaryDirectory())
    await #expect(throws: AITextError.emptyOutput) {
        _ = try await runner.run(command: "cat >/dev/null", prompt: "x", timeout: 5)
    }
}

@Test func runnerCancel() async throws {
    let runner = AITextRunner(workingDirectory: temporaryDirectory())
    let start = ContinuousClock.now
    let task = Task { try await runner.run(command: "sleep 5", prompt: "x", timeout: 10) }
    try await Task.sleep(for: .milliseconds(200))
    await runner.cancel()
    await #expect(throws: AITextError.cancelled) { _ = try await task.value }
    #expect(start.duration(to: .now) < .seconds(2))
}

@Test func textNeverEntersShellText() async throws {
    let marker = "/tmp/uficast-injected"
    try? FileManager.default.removeItem(atPath: marker)
    let prompt = "$(touch \(marker)); \"'"
    let runner = AITextRunner(workingDirectory: temporaryDirectory())
    #expect(try await runner.run(command: "cat", prompt: prompt, timeout: 5) == prompt)
    #expect(!FileManager.default.fileExists(atPath: marker))
}
