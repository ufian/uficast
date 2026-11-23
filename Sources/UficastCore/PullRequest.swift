import Foundation

public struct PullRequest: Identifiable, Hashable, Sendable {
    public var number: Int
    public var title: String
    public var url: URL
    /// `owner/repo`.
    public var repository: String
    public var createdAt: Date
    public var isDraft: Bool
    public var id: String { url.absoluteString }

    public init(number: Int, title: String, url: URL, repository: String, createdAt: Date, isDraft: Bool) {
        self.number = number
        self.title = title
        self.url = url
        self.repository = repository
        self.createdAt = createdAt
        self.isDraft = isDraft
    }
}

public enum PullRequestError: Error, LocalizedError, Equatable {
    case notInstalled, unexpectedOutput, failed(String), cancelled

    public var errorDescription: String? {
        switch self {
        case .notInstalled: "GitHub CLI (gh) is not installed. Install it (brew install gh), then run gh auth login."
        case .unexpectedOutput: "Unexpected output from gh."
        case .failed(let message): message
        case .cancelled: "Cancelled."
        }
    }
}

public protocol PullRequestLoading: Sendable {
    func load() async throws -> [PullRequest]
}

public enum PullRequestParser {
    private struct Row: Decodable {
        struct Repository: Decodable { var nameWithOwner: String? }
        var number: Int?
        var title: String?
        var url: String?
        var repository: Repository?
        var createdAt: String?
        var isDraft: Bool?
    }

    /// Rows are decoded one by one, so a single malformed row is dropped without
    /// losing the others. Only a non-array top level fails.
    public static func parse(_ json: Data) throws -> [PullRequest] {
        guard let rows = try? JSONDecoder().decode([Lenient<Row>].self, from: json) else {
            throw PullRequestError.unexpectedOutput
        }
        let formatter = ISO8601DateFormatter()
        return rows.compactMap { $0.value.flatMap { pullRequest($0, formatter: formatter) } }
    }

    private static func pullRequest(_ row: Row, formatter: ISO8601DateFormatter) -> PullRequest? {
        guard let number = row.number,
              let title = row.title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let urlText = row.url, let url = URL(string: urlText),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              let host = url.host, !host.isEmpty,
              let repository = row.repository?.nameWithOwner, !repository.isEmpty,
              let created = row.createdAt, let createdAt = formatter.date(from: created)
        else { return nil }
        return PullRequest(number: number, title: title, url: url, repository: repository,
                           createdAt: createdAt, isDraft: row.isDraft ?? false)
    }

    private struct Lenient<Value: Decodable>: Decodable {
        var value: Value?
        init(from decoder: Decoder) throws {
            value = try? decoder.singleValueContainer().decode(Value.self)
        }
    }
}

public enum PullRequestFilter {
    public static func apply(_ query: String, to pullRequests: [PullRequest]) -> [PullRequest] {
        let variants = KeyboardLayoutSearch.variants(query).filter { !$0.isEmpty }.map(Array.init)
        guard !variants.isEmpty else {
            return pullRequests.sorted(by: newestFirst)
        }
        var scored = [(pullRequest: PullRequest, score: Int)]()
        for pullRequest in pullRequests {
            let title = Array(SearchText.normalize(pullRequest.title))
            let best = variants.compactMap { SearchIndex.fuzzyScore(query: $0, name: title) }.max()
            if let best { scored.append((pullRequest, best)) }
        }
        scored.sort { left, right in
            left.score != right.score ? left.score > right.score : newestFirst(left.pullRequest, right.pullRequest)
        }
        return scored.map(\.pullRequest)
    }

    private static func newestFirst(_ left: PullRequest, _ right: PullRequest) -> Bool {
        left.createdAt != right.createdAt ? left.createdAt > right.createdAt : left.number > right.number
    }
}

extension LauncherEntry {
    public static func pullRequest(_ pullRequest: PullRequest) -> LauncherEntry {
        LauncherEntry(id: "pr:" + pullRequest.url.absoluteString, name: pullRequest.title, kind: .pullRequest,
                      fileURL: pullRequest.url,
                      alias: "\(pullRequest.repository) #\(pullRequest.number)" + (pullRequest.isDraft ? " · Draft" : ""))
    }
}
