import Foundation

/// Shares one pull request load between callers and keeps a successful list for
/// `lifetime` seconds. Failures are never cached. The list lives in memory only.
public actor PullRequestStore {
    public static let defaultLifetime: TimeInterval = 300

    private let loader: any PullRequestLoading
    private let lifetime: TimeInterval
    private let now: @Sendable () -> Date
    private var cache: (rows: [PullRequest], loadedAt: Date)?
    private var inFlight: (id: UUID, task: Task<[PullRequest], Error>)?

    public init(loader: any PullRequestLoading, lifetime: TimeInterval = PullRequestStore.defaultLifetime,
                now: @escaping @Sendable () -> Date = { Date() }) {
        self.loader = loader
        self.lifetime = lifetime
        self.now = now
    }

    /// The cached list, or nil when nothing is cached or the list is older than the lifetime.
    public var cached: [PullRequest]? {
        guard let cache, now().timeIntervalSince(cache.loadedAt) <= lifetime else { return nil }
        return cache.rows
    }

    public func list() async throws -> [PullRequest] {
        if let rows = cached { return rows }
        // Awaiting the value of an unstructured task does not pass the caller's
        // cancellation on to the shared load.
        return try await (inFlight?.task ?? startLoad()).value
    }

    /// Drops the cached list. A load that is already running still caches its result.
    public func invalidate() {
        cache = nil
    }

    /// Cancels the running load. Nothing is cached and waiting callers get `.cancelled`.
    public func cancel() {
        inFlight?.task.cancel()
        inFlight = nil
    }

    private func startLoad() -> Task<[PullRequest], Error> {
        let id = UUID()
        let loader = loader
        let task = Task { () throws -> [PullRequest] in
            let result: Result<[PullRequest], Error>
            do {
                result = .success(try await loader.load())
            } catch {
                result = .failure(error)
            }
            let cancelled = Task.isCancelled
            if inFlight?.id == id { inFlight = nil }
            if cancelled { throw PullRequestError.cancelled }
            let rows = try result.get()
            cache = (rows, now())
            return rows
        }
        inFlight = (id, task)
        return task
    }
}
