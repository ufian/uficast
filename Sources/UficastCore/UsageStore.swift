import Foundation

/// Local remembered launch counts, keyed by launcher entry ID. It holds only
/// identifiers, counts and dates (never arguments or paths) and, like the
/// remembered Keep Awake session and calculator history, stays out of the
/// exported configuration.
public enum UsageStore {
    /// Entries beyond this many (least recently used first) are dropped, so
    /// uninstalled apps cannot grow the stored data without bound.
    public static let limit = 1000

    public static func decode(_ data: Data?) -> [String: UsageRecord] {
        guard let data, let stored = try? JSONDecoder().decode([String: UsageRecord].self, from: data) else { return [:] }
        return stored.filter { $0.value.count > 0 }
    }

    public static func encode(_ usage: [String: UsageRecord]) -> Data? {
        let kept = usage.filter { $0.value.count > 0 }.sorted { $0.value.lastUsed > $1.value.lastUsed }.prefix(limit)
        return try? JSONEncoder().encode(Dictionary(uniqueKeysWithValues: kept.map { ($0.key, $0.value) }))
    }
}
