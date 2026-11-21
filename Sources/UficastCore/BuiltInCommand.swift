import Foundation

public enum BuiltInCommand: String, CaseIterable, Sendable {
    case caffeine, decaffeine
    case pullRequests = "gh"

    public init?(entryID: String) {
        guard entryID.hasPrefix("builtin:") else { return nil }
        self.init(rawValue: String(entryID.dropFirst("builtin:".count)))
    }

    public var keepsAwake: Bool { self == .caffeine }
    public var symbolName: String {
        switch self {
        case .caffeine: "cup.and.saucer.fill"
        case .decaffeine: "zzz"
        case .pullRequests: "arrow.triangle.pull"
        }
    }
    public var entry: LauncherEntry {
        LauncherEntry(id: "builtin:\(rawValue)", name: displayName, kind: .builtIn,
                      fileURL: URL(string: "uficast://command/\(rawValue)")!,
                      alias: alias, matchesAliasByPrefix: self != .pullRequests)
    }
    private var displayName: String { self == .pullRequests ? "GitHub Pull Requests" : rawValue }
    private var alias: String {
        switch self {
        case .caffeine: "cafe"
        case .decaffeine: "decafe"
        case .pullRequests: "gh"
        }
    }
    public static var entries: [LauncherEntry] { allCases.map(\.entry) }
}
