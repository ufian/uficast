import Foundation

/// Where the GitHub CLI lives and how it is called. A GUI app does not inherit the
/// owner's shell PATH, so the usual install folders are searched after the app's own.
public enum GitHubCLI {
    public static let standardDirectories = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin", "/usr/sbin", "/sbin"]

    public static let arguments = ["search", "prs", "--author", "@me", "--state", "open", "--sort", "created",
                                   "--order", "desc", "--limit", "100", "--json", "number,title,url,repository,createdAt,isDraft"]

    /// The entries of `path` first, then the standard folders. Only absolute, non-empty
    /// entries are kept, so `.` and relative entries never pick a program from the
    /// current folder. A repeated folder keeps its first position.
    public static func searchDirectories(path: String?) -> [String] {
        let entries = (path?.split(separator: ":", omittingEmptySubsequences: true).map(String.init) ?? []) + standardDirectories
        var seen = Set<String>()
        return entries.filter { $0.hasPrefix("/") && seen.insert($0).inserted }
    }

    /// An existing regular file (a symlink is followed) with an execute bit.
    public static func isRegularExecutable(_ path: String) -> Bool {
        var info = stat()
        return stat(path, &info) == 0 && (info.st_mode & S_IFMT) == S_IFREG && access(path, X_OK) == 0
    }

    public static func locate(in directories: [String],
                              isExecutable: (String) -> Bool = GitHubCLI.isRegularExecutable) -> String? {
        directories.lazy.map { ($0 as NSString).appendingPathComponent("gh") }.first(where: isExecutable)
    }
}

public struct GitHubPullRequestLoader: PullRequestLoading {
    public typealias RunProcess = @Sendable (_ executable: String, _ arguments: [String], _ environment: [String: String],
                                             _ directory: String, _ timeout: Double) async throws -> ScriptResult

    private static let timeout = 30.0

    private let environment: [String: String]
    private let isExecutable: @Sendable (String) -> Bool
    private let run: RunProcess

    public init(environment: [String: String] = ProcessInfo.processInfo.environment,
                isExecutable: @escaping @Sendable (String) -> Bool = GitHubCLI.isRegularExecutable,
                run: @escaping RunProcess = GitHubPullRequestLoader.runNative) {
        self.environment = environment
        self.isExecutable = isExecutable
        self.run = run
    }

    public func load() async throws -> [PullRequest] {
        let directories = GitHubCLI.searchDirectories(path: environment["PATH"])
        guard let executable = GitHubCLI.locate(in: directories, isExecutable: isExecutable) else {
            throw PullRequestError.notInstalled
        }
        var childEnvironment = environment
        childEnvironment["PATH"] = directories.joined(separator: ":")
        childEnvironment["GH_PROMPT_DISABLED"] = "1"
        childEnvironment["NO_COLOR"] = "1"
        childEnvironment["GH_NO_UPDATE_NOTIFIER"] = "1"
        let result = try await run(executable, GitHubCLI.arguments, childEnvironment,
                                   FileManager.default.temporaryDirectory.path, Self.timeout)
        switch result.termination {
        case .timedOut: throw PullRequestError.failed("Timed out after \(String(format: "%g", Self.timeout)) s.")
        case .cancelled: throw PullRequestError.cancelled
        case .exited: break
        }
        guard result.exitCode == 0 else {
            throw PullRequestError.failed(result.failureDescription ?? "Exit code \(result.exitCode)")
        }
        guard !result.stdoutTruncated else { throw PullRequestError.unexpectedOutput }
        return try PullRequestParser.parse(result.stdout)
    }

    /// Runs the program directly, with no shell, and stops it when the calling task is cancelled.
    @Sendable public static func runNative(executable: String, arguments: [String], environment: [String: String],
                                           directory: String, timeout: Double) async throws -> ScriptResult {
        do {
            let session = try NativeRun()
            return try await withTaskCancellationHandler {
                try await session.execute(executable: executable, arguments: arguments, environment: environment,
                                          directory: directory, timeout: timeout)
            } onCancel: { session.cancel() }
        } catch let error as ScriptRunError {
            throw PullRequestError.failed(error.localizedDescription)
        }
    }
}
