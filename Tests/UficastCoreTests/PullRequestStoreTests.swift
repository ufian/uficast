import Foundation
import Synchronization
import Testing
import UficastCore

private func pullRequest(_ number: Int, _ title: String = "Fix upload") -> PullRequest {
    PullRequest(number: number, title: title, url: URL(string: "https://example.com/org/repo/pull/\(number)")!,
                repository: "org/repo", createdAt: Date(timeIntervalSince1970: 1_800_000_000), isDraft: false)
}

/// A loader that counts calls and suspends each one until the test settles it.
private actor GatedLoader: PullRequestLoading {
    private(set) var loadCount = 0
    private var pending: [CheckedContinuation<[PullRequest], Error>] = []
    private var startWaiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []

    func load() async throws -> [PullRequest] {
        loadCount += 1
        let ready = startWaiters.filter { $0.count <= loadCount }
        startWaiters.removeAll { $0.count <= loadCount }
        for waiter in ready { waiter.continuation.resume() }
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                if Task.isCancelled {
                    continuation.resume(throwing: PullRequestError.cancelled)
                } else {
                    pending.append(continuation)
                }
            }
        } onCancel: {
            Task { await self.failPending(PullRequestError.cancelled) }
        }
    }

    /// Returns once `load()` has been called `count` times in total.
    func waitForLoads(_ count: Int) async {
        guard loadCount < count else { return }
        await withCheckedContinuation { startWaiters.append((count, $0)) }
    }

    func succeed(_ rows: [PullRequest]) {
        guard !pending.isEmpty else { return }
        pending.removeFirst().resume(returning: rows)
    }

    func fail(_ error: PullRequestError) { failPending(error) }

    private func failPending(_ error: PullRequestError) {
        let waiting = pending
        pending = []
        for continuation in waiting { continuation.resume(throwing: error) }
    }
}

private final class TestClock: Sendable {
    private let current = Mutex(Date(timeIntervalSince1970: 1_800_000_000))
    var now: Date { current.withLock { $0 } }
    func advance(by seconds: TimeInterval) { current.withLock { $0 = $0.addingTimeInterval(seconds) } }
}

private func makeStore(_ loader: GatedLoader, clock: TestClock = TestClock()) -> PullRequestStore {
    PullRequestStore(loader: loader, now: { clock.now })
}

/// Runs one `list()` that makes the loader start, then settles it with `rows`.
@discardableResult
private func loadOnce(_ store: PullRequestStore, _ loader: GatedLoader, total: Int,
                      rows: [PullRequest]) async throws -> [PullRequest] {
    let call = Task { try await store.list() }
    await loader.waitForLoads(total)
    await loader.succeed(rows)
    return try await call.value
}

@Test func concurrentCallsShareOneLoadAndSuccessIsCached() async throws {
    let loader = GatedLoader()
    let store = makeStore(loader)
    let rows = [pullRequest(1), pullRequest(2)]
    let first = Task { try await store.list() }
    let second = Task { try await store.list() }
    await loader.waitForLoads(1)
    await loader.succeed(rows)
    #expect(try await first.value == rows)
    #expect(try await second.value == rows)
    #expect(await loader.loadCount == 1)
    #expect(try await store.list() == rows)
    #expect(await loader.loadCount == 1)
    #expect(await store.cached == rows)
}

@Test func failureIsNotCachedAndNextCallStartsFreshLoad() async throws {
    let loader = GatedLoader()
    let store = makeStore(loader)
    let failing = Task { try await store.list() }
    await loader.waitForLoads(1)
    await loader.fail(.failed("x"))
    await #expect(throws: PullRequestError.failed("x")) { try await failing.value }
    #expect(await store.cached == nil)

    let rows = [pullRequest(3)]
    #expect(try await loadOnce(store, loader, total: 2, rows: rows) == rows)
    #expect(await loader.loadCount == 2)
}

@Test func callerCancellationDoesNotCancelSharedLoad() async throws {
    let loader = GatedLoader()
    let store = makeStore(loader)
    let rows = [pullRequest(4)]
    let cancelledCaller = Task { try await store.list() }
    await loader.waitForLoads(1)
    let waitingCaller = Task { try await store.list() }
    cancelledCaller.cancel()
    await loader.succeed(rows)
    #expect(try await waitingCaller.value == rows)
    #expect(await loader.loadCount == 1)
    #expect(await store.cached == rows)
}

@Test func cancelStopsInFlightLoadWithoutCaching() async throws {
    let loader = GatedLoader()
    let store = makeStore(loader)
    let call = Task { try await store.list() }
    await loader.waitForLoads(1)
    await store.cancel()
    await #expect(throws: PullRequestError.cancelled) { try await call.value }
    #expect(await store.cached == nil)

    let rows = [pullRequest(5)]
    #expect(try await loadOnce(store, loader, total: 2, rows: rows) == rows)
    #expect(await loader.loadCount == 2)
}

@Test func emptyListIsCached() async throws {
    let loader = GatedLoader()
    let store = makeStore(loader)
    #expect(try await loadOnce(store, loader, total: 1, rows: []).isEmpty)
    #expect(await store.cached == [])
    #expect(try await store.list().isEmpty)
    #expect(await loader.loadCount == 1)
}

@Test func cacheIsKeptWithinLifetime() async throws {
    let loader = GatedLoader()
    let clock = TestClock()
    let store = makeStore(loader, clock: clock)
    let rows = [pullRequest(6)]
    try await loadOnce(store, loader, total: 1, rows: rows)
    clock.advance(by: 299)
    #expect(await store.cached == rows)
    #expect(try await store.list() == rows)
    #expect(await loader.loadCount == 1)
}

@Test func expiredCacheStartsFreshLoad() async throws {
    let loader = GatedLoader()
    let clock = TestClock()
    let store = makeStore(loader, clock: clock)
    try await loadOnce(store, loader, total: 1, rows: [pullRequest(7)])
    clock.advance(by: 301)
    #expect(await store.cached == nil)

    let fresh = [pullRequest(8)]
    #expect(try await loadOnce(store, loader, total: 2, rows: fresh) == fresh)
    #expect(await loader.loadCount == 2)

    // The lifetime counts from the moment the second load finished.
    clock.advance(by: 299)
    #expect(await store.cached == fresh)
    clock.advance(by: 2)
    #expect(await store.cached == nil)
}

@Test func invalidateClearsCache() async throws {
    let loader = GatedLoader()
    let store = makeStore(loader)
    try await loadOnce(store, loader, total: 1, rows: [pullRequest(9)])
    await store.invalidate()
    #expect(await store.cached == nil)

    let rows = [pullRequest(10)]
    #expect(try await loadOnce(store, loader, total: 2, rows: rows) == rows)
    #expect(await loader.loadCount == 2)
}

@Test func invalidateDuringLoadStillCachesItsResult() async throws {
    let loader = GatedLoader()
    let store = makeStore(loader)
    let rows = [pullRequest(11)]
    let call = Task { try await store.list() }
    await loader.waitForLoads(1)
    await store.invalidate()
    await loader.succeed(rows)
    #expect(try await call.value == rows)
    #expect(await store.cached == rows)
    #expect(await loader.loadCount == 1)
}
