import Foundation
import Testing
import UficastCore

private func json(_ rows: String) -> Data { Data(rows.utf8) }

private func row(number: Int = 1, title: String = "Fix upload", url: String = "https://example.com/org/repo/pull/1",
                 repository: String = "org/repo", createdAt: String = "2026-11-19T01:54:48Z",
                 isDraft: Bool = false) -> String {
    let escaped = title.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    return """
    {"number": \(number), "title": "\(escaped)", "url": "\(url)", "repository": {"nameWithOwner": "\(repository)"},
     "createdAt": "\(createdAt)", "isDraft": \(isDraft)}
    """
}

private func date(_ iso: String) -> Date { ISO8601DateFormatter().date(from: iso)! }

private func pullRequest(_ number: Int, _ title: String, _ iso: String = "2026-11-19T01:54:48Z") -> PullRequest {
    PullRequest(number: number, title: title, url: URL(string: "https://example.com/org/repo/pull/\(number)")!,
                repository: "org/repo", createdAt: date(iso), isDraft: false)
}

@Test func parserReadsGhJsonAndDropsInvalidRows() throws {
    let rows = [
        row(number: 11, title: "Add retry", url: "https://example.com/org/repo/pull/11"),
        row(number: 12, title: ""),
        row(number: 13, url: "javascript:alert(1)"),
        row(number: 14, url: "https:///x"),
        row(number: 15, title: "Draft work", url: "https://example.com/org/api/pull/15", repository: "org/api",
            createdAt: "2026-11-18T10:00:00Z", isDraft: true),
    ].joined(separator: ",")
    let result = try PullRequestParser.parse(json("[\(rows)]"))
    #expect(result.map(\.number) == [11, 15])
    #expect(result[0].title == "Add retry")
    #expect(result[0].url == URL(string: "https://example.com/org/repo/pull/11"))
    #expect(result[0].repository == "org/repo")
    #expect(result[0].createdAt == date("2026-11-19T01:54:48Z"))
    #expect(result[0].isDraft == false)
    #expect(result[1].repository == "org/api")
    #expect(result[1].createdAt == date("2026-11-18T10:00:00Z"))
    #expect(result[1].isDraft)
    #expect(result[1].id == "https://example.com/org/api/pull/15")
}

@Test func parserRejectsNonArrayAndInvalidJson() throws {
    for input in ["{}", "not json", ""] {
        #expect(throws: PullRequestError.unexpectedOutput) { try PullRequestParser.parse(json(input)) }
    }
    #expect(try PullRequestParser.parse(json("[]")).isEmpty)
}

@Test func parserKeepsUnicodeTitlesAndDropsRowsMissingFields() throws {
    let title = "Исправить 🚀 \"quotes\""
    let missingRepository = """
    {"number": 2, "title": "No repo", "url": "https://example.com/p/2", "createdAt": "2026-11-19T01:54:48Z", "isDraft": false}
    """
    let rows = [row(number: 1, title: title), missingRepository, row(number: 3, createdAt: "yesterday")]
    let result = try PullRequestParser.parse(json("[\(rows.joined(separator: ","))]"))
    #expect(result.map(\.number) == [1])
    #expect(result[0].title == title)
}

@Test func filterBlankQueryOrdersNewestFirst() {
    let items = [
        pullRequest(1, "Old", "2026-11-01T00:00:00Z"),
        pullRequest(2, "Newest", "2026-11-19T00:00:00Z"),
        pullRequest(3, "Middle", "2026-11-10T00:00:00Z"),
        pullRequest(4, "Tie low", "2026-11-05T00:00:00Z"),
        pullRequest(5, "Tie high", "2026-11-05T00:00:00Z"),
    ]
    for query in ["", "   "] {
        #expect(PullRequestFilter.apply(query, to: items).map(\.number) == [2, 3, 5, 4, 1])
    }
}

@Test func filterFuzzyMatchesTitleAndTiesNewestFirst() {
    let items = [
        pullRequest(1, "Fix flaky retry in upload"),
        pullRequest(2, "Flaky cache test"),
        pullRequest(3, "Unrelated"),
    ]
    let result = PullRequestFilter.apply("flaky", to: items)
    #expect(Set(result.map(\.number)) == [1, 2])
    let tied = [
        pullRequest(4, "Fix cache", "2026-11-01T00:00:00Z"),
        pullRequest(5, "Fix cache", "2026-11-10T00:00:00Z"),
    ]
    #expect(PullRequestFilter.apply("fix", to: tied).map(\.number) == [5, 4])
}

@Test func filterUsesWrongLayoutVariantsForTheQueryOnly() {
    let items = [pullRequest(1, "Fix upload"), pullRequest(2, "Исправить")]
    #expect(PullRequestFilter.apply("аш", to: items).map(\.number) == [1])
    #expect(PullRequestFilter.apply("исп", to: items).map(\.number) == [2])
}

@Test func filterReturnsNothingForNoMatch() {
    #expect(PullRequestFilter.apply("zzzz", to: [pullRequest(1, "Fix upload")]).isEmpty)
}

@Test func entryCarriesUrlKindAndLabels() {
    let url = URL(string: "https://example.com/org/api/pull/412")!
    let draft = PullRequest(number: 412, title: "Add endpoint", url: url, repository: "org/api",
                            createdAt: date("2026-11-19T01:54:48Z"), isDraft: true)
    let entry = LauncherEntry.pullRequest(draft)
    #expect(entry.kind == .pullRequest)
    #expect(entry.fileURL == url)
    #expect(entry.name == "Add endpoint")
    #expect(entry.id == "pr:https://example.com/org/api/pull/412")
    #expect(entry.alias == "org/api #412 · Draft")
    #expect(LauncherEntry.pullRequest(pullRequest(7, "Plain")).alias == "org/repo #7")
}

@Test func errorsHaveTheDocumentedTexts() {
    #expect(PullRequestError.notInstalled.errorDescription
            == "GitHub CLI (gh) is not installed. Install it (brew install gh), then run gh auth login.")
    #expect(PullRequestError.unexpectedOutput.errorDescription == "Unexpected output from gh.")
    #expect(PullRequestError.failed("boom").errorDescription == "boom")
    #expect(PullRequestError.cancelled.errorDescription == "Cancelled.")
}
