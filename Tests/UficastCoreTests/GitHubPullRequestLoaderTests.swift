import Foundation
import Testing
@testable import UficastCore

private let validRow = """
[{"number": 7, "title": "Fix upload", "url": "https://example.com/org/repo/pull/7",
  "repository": {"nameWithOwner": "org/repo"}, "createdAt": "2026-11-19T01:54:48Z", "isDraft": false}]
"""

private struct RecordedRun: Sendable {
    var executable: String
    var arguments: [String]
    var environment: [String: String]
    var timeout: Double
}

private final class RunRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var runs: [RecordedRun] = []
    var recorded: [RecordedRun] { lock.withLock { runs } }
    func record(_ run: RecordedRun) { lock.withLock { runs.append(run) } }
}

private func result(exitCode: Int32 = 0, termination: ScriptResult.Termination = .exited, stdout: String = "",
                    stderr: String = "", stdoutTruncated: Bool = false) -> ScriptResult {
    ScriptResult(exitCode: exitCode, termination: termination, stdout: Data(stdout.utf8), stderr: Data(stderr.utf8),
                 stdoutTruncated: stdoutTruncated, stderrTruncated: false)
}

private func loader(returning outcome: ScriptResult, recorder: RunRecorder = RunRecorder(),
                    environment: [String: String] = ["PATH": "/fixture/bin"]) -> GitHubPullRequestLoader {
    GitHubPullRequestLoader(environment: environment, isExecutable: { $0 == "/fixture/bin/gh" }) {
        executable, arguments, environment, _, timeout in
        recorder.record(RecordedRun(executable: executable, arguments: arguments, environment: environment, timeout: timeout))
        return outcome
    }
}

private func temporaryFolder() throws -> URL {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("uficast-gh-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    return folder
}

@Test func locateIgnoresUnsafeDirectoriesAndNonExecutables() throws {
    let expected = ["/a", "/b"] + GitHubCLI.standardDirectories.filter { $0 != "/a" && $0 != "/b" }
    #expect(GitHubCLI.searchDirectories(path: ":.:relative/bin:/a:/a:/b") == expected)
    #expect(GitHubCLI.searchDirectories(path: nil) == GitHubCLI.standardDirectories)

    let root = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: root) }
    let directoryCase = root.appendingPathComponent("one")
    let plainCase = root.appendingPathComponent("two")
    let executableCase = root.appendingPathComponent("three")
    try FileManager.default.createDirectory(at: directoryCase.appendingPathComponent("gh"), withIntermediateDirectories: true)
    for (folder, mode) in [(plainCase, 0o644), (executableCase, 0o755)] {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent("gh")
        try Data("#!/bin/sh\n".utf8).write(to: file)
        try FileManager.default.setAttributes([.posixPermissions: mode], ofItemAtPath: file.path)
    }
    let all = [directoryCase.path, plainCase.path, executableCase.path]
    #expect(GitHubCLI.locate(in: all) == executableCase.appendingPathComponent("gh").path)
    #expect(GitHubCLI.locate(in: Array(all.prefix(2))) == nil)
}

@Test func loaderRunsExactArgvWithPathAndQuietEnvironment() async throws {
    let recorder = RunRecorder()
    let pullRequests = try await loader(returning: result(stdout: validRow), recorder: recorder,
                                        environment: ["PATH": "/fixture/bin", "HOME": "/home/fixture"]).load()
    let run = try #require(recorder.recorded.first)
    #expect(recorder.recorded.count == 1)
    #expect(run.executable == "/fixture/bin/gh")
    #expect(run.arguments == GitHubCLI.arguments)
    #expect(run.arguments == ["search", "prs", "--author", "@me", "--state", "open", "--sort", "created", "--order", "desc",
                              "--limit", "100", "--json", "number,title,url,repository,createdAt,isDraft"])
    #expect(run.environment["PATH"]?.hasPrefix("/fixture/bin:") == true)
    #expect(run.environment["PATH"]?.contains("/opt/homebrew/bin") == true)
    #expect(run.environment["HOME"] == "/home/fixture")
    for name in ["GH_PROMPT_DISABLED", "NO_COLOR", "GH_NO_UPDATE_NOTIFIER"] { #expect(run.environment[name] == "1") }
    #expect(run.timeout == 30)
    #expect(pullRequests.map(\.number) == [7])
}

@Test func loaderThrowsNotInstalledWithoutRunning() async {
    let recorder = RunRecorder()
    let missing = GitHubPullRequestLoader(environment: ["PATH": "/fixture/bin"], isExecutable: { _ in false }) {
        executable, arguments, environment, _, timeout in
        recorder.record(RecordedRun(executable: executable, arguments: arguments, environment: environment, timeout: timeout))
        return result()
    }
    await #expect(throws: PullRequestError.notInstalled) { try await missing.load() }
    #expect(recorder.recorded.isEmpty)
    #expect(PullRequestError.notInstalled.errorDescription
            == "GitHub CLI (gh) is not installed. Install it (brew install gh), then run gh auth login.")
}

@Test func loaderMapsFailures() async {
    let stderr = "To get started with GitHub CLI, please run:  gh auth login"
    let failure = await #expect(throws: PullRequestError.self) {
        try await loader(returning: result(exitCode: 4, stderr: stderr)).load()
    }
    guard case .failed(let message) = failure else {
        Issue.record("Expected .failed, got \(String(describing: failure))")
        return
    }
    #expect(message.contains("Exit code 4"))
    #expect(message.contains(stderr))

    await #expect(throws: PullRequestError.failed("Timed out after 30 s.")) {
        try await loader(returning: result(exitCode: -1, termination: .timedOut)).load()
    }
    await #expect(throws: PullRequestError.cancelled) {
        try await loader(returning: result(exitCode: -1, termination: .cancelled)).load()
    }
    await #expect(throws: PullRequestError.unexpectedOutput) {
        try await loader(returning: result(stdout: validRow, stdoutTruncated: true)).load()
    }
    await #expect(throws: PullRequestError.unexpectedOutput) {
        try await loader(returning: result(stdout: "not json")).load()
    }
}

@Test func defaultRunnerExecutesAFakeGhFromPath() async throws {
    let folder = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let script = folder.appendingPathComponent("gh")
    let oneLine = validRow.replacingOccurrences(of: "\n", with: " ")
    try Data("#!/bin/sh\nprintf '%s' '\(oneLine)'\n".utf8).write(to: script)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
    let pullRequests = try await GitHubPullRequestLoader(environment: ["PATH": folder.path]).load()
    #expect(pullRequests.count == 1)
    #expect(pullRequests.first?.title == "Fix upload")
}
