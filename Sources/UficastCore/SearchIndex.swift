import Foundation

public struct SearchIndex: Sendable {
    private struct Indexed: Sendable {
        var entry: LauncherEntry
        var name: String
        var characters: [Character]
        var alias: String?
    }
    private struct Match {
        var indexed: Indexed
        var tier: Int
        var score: Int
        var variant: Int
        var usage: UsageRecord
    }
    private var items: [Indexed]

    public init(entries: [LauncherEntry] = []) {
        items = entries.filter(\.isEnabled).map {
            let name = SearchText.normalize($0.name)
            return Indexed(entry: $0, name: name, characters: Array(name), alias: $0.alias.map(SearchText.normalize))
        }
    }

    public func search(_ text: String, usage: [String: UsageRecord] = [:], limit: Int = 50) -> [LauncherEntry] {
        guard limit > 0 else { return [] }
        let queries = KeyboardLayoutSearch.variants(text).map { ($0, Array($0)) }
        var matches = [Match]()
        for item in items {
            var best: Match?
            for (priority, query) in queries.enumerated() {
                guard let rank = Self.rank(item, query: query.0, characters: query.1) else { continue }
                let candidate = Match(indexed: item, tier: rank.tier, score: rank.score, variant: priority,
                                      usage: usage[item.entry.id] ?? UsageRecord())
                if let current = best, !Self.precedes(candidate, current) { continue }
                best = candidate
            }
            if let best { matches.append(best) }
        }
        matches.sort(by: Self.precedes)
        return matches.prefix(limit).map(\.indexed.entry)
    }

    private static func rank(_ item: Indexed, query: String, characters: [Character]) -> (tier: Int, score: Int)? {
        let tier: Int
        let score: Int
        if query.isEmpty { tier = 6; score = 0 }
        else if item.alias == query { tier = 0; score = 0 }
        else if item.entry.matchesAliasByPrefix, let alias = item.alias, alias.hasPrefix(query) { tier = 1; score = 0 }
        else if item.name == query { tier = 2; score = 0 }
        else if item.name.hasPrefix(query) { tier = 3; score = 0 }
        else if item.name.contains(query) { tier = 4; score = 0 }
        else if let fuzzy = Self.fuzzyScore(query: characters, name: item.characters) { tier = 5; score = fuzzy }
        else { return nil }
        return (tier, score)
    }

    private static func precedes(_ left: Match, _ right: Match) -> Bool {
        if left.tier != right.tier { return left.tier < right.tier }
        if left.variant != right.variant { return left.variant < right.variant }
        if left.score != right.score { return left.score > right.score }
        // Built-in abbreviations are defaults; an explicit user alias can
        // override one without invalidating an existing configuration.
        if left.tier <= 1, (left.indexed.entry.kind == .builtIn) != (right.indexed.entry.kind == .builtIn) {
            return left.indexed.entry.kind != .builtIn
        }
        if left.usage.count != right.usage.count { return left.usage.count > right.usage.count }
        if left.usage.lastUsed != right.usage.lastUsed { return left.usage.lastUsed > right.usage.lastUsed }
        if left.indexed.name != right.indexed.name { return left.indexed.name < right.indexed.name }
        return left.indexed.entry.id < right.indexed.entry.id
    }

    static func fuzzyScore(query: [Character], name: [Character]) -> Int? {
        var next = 0
        var previous = -2
        var score = 0
        for (index, character) in name.enumerated() where next < query.count {
            guard character == query[next] else { continue }
            score += previous == index - 1 ? 12 : 0
            if index == 0 || !name[index - 1].isLetter && !name[index - 1].isNumber { score += 10 }
            score -= index - previous - 1
            previous = index
            next += 1
        }
        return next == query.count ? score : nil
    }
}
