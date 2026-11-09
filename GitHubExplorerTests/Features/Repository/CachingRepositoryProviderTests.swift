import Testing
@testable import GitHubExplorer

@MainActor
struct CachingRepositoryProviderTests {

    @Test
    func expiredEntryFetchesUpdatedRepository() async throws {
        let provider = UpdatingRepositoryProvider()
        let cache = CachingRepositoryProvider(wrapping: provider, cacheLifetime: 0)
        let first = try await cache.fetchRepository(owner: "apple", name: "swift")
        let second = try await cache.fetchRepository(owner: "apple", name: "swift")
        #expect(first.stars == 1)
        #expect(second.stars == 2)
    }

    @Test
    func returnsCachedRepository() async throws {
        let repository = GitHubRepository(
            id: 1,
            name: "swift",
            fullName: "apple/swift",
            stars: 100
        )

        let provider = CountingRepositoryProvider(
            repository: repository
        )

        let cache = CachingRepositoryProvider(
            wrapping: provider
        )

        _ = try await cache.fetchRepository(
            owner: "apple",
            name: "swift"
        )

        _ = try await cache.fetchRepository(
            owner: "apple",
            name: "swift"
        )

        let count = await provider.fetchCount
        #expect(count == 1)
    }
}

actor CountingRepositoryProvider: GitHubRepositoryProviding {

    let repository: GitHubRepository
    private(set) var fetchCount = 0

    init(repository: GitHubRepository) {
        self.repository = repository
    }

    func fetchRepository(
        owner: String,
        name: String
    ) async throws -> GitHubRepository {
        fetchCount += 1
        return repository
    }

    func searchRepositories(
        query: String
    ) async throws -> GitHubSearchResponse {
        GitHubSearchResponse(totalCount: 0, items: [])
    }

}

private actor UpdatingRepositoryProvider: GitHubRepositoryProviding {
    private var count = 0

    func fetchRepository(owner: String, name: String) async throws -> GitHubRepository {
        count += 1
        return GitHubRepository(id: 1, name: name, fullName: "\(owner)/\(name)", stars: count)
    }

    func searchRepositories(query: String) async throws -> GitHubSearchResponse {
        GitHubSearchResponse(totalCount: 0, items: [])
    }
}

extension CachingRepositoryProviderTests {
    @Test
    func concurrentMissesAreIndependent() async throws {
        let provider = ControlledCacheProvider()
        let cache = CachingRepositoryProvider(wrapping: provider)
        let first = Task {
            try await cache.fetchRepository(owner: "apple", name: "swift")
        }
        await provider.waitUntilRequested(0)

        let second = Task {
            try await cache.fetchRepository(owner: "apple", name: "swift")
        }
        await provider.waitUntilRequested(1)
        first.cancel()

        // Complete the surviving caller first, then the canceled caller.
        await provider.complete(1, stars: 200)
        let result = try await second.value
        #expect(result.stars == 200)

        await provider.complete(0, stars: 100)
        await #expect(throws: CancellationError.self) {
            try await first.value
        }

        let cached = try await cache.fetchRepository(owner: "apple", name: "swift")
        #expect(cached.stars == 200)
        #expect(await provider.fetchCount == 2)
    }

    @Test
    func cancelledResponseIsNotCached() async throws {
        let provider = ControlledCacheProvider()
        let cache = CachingRepositoryProvider(wrapping: provider)
        let first = Task {
            try await cache.fetchRepository(owner: "apple", name: "swift")
        }
        await provider.waitUntilRequested(0)
        first.cancel()
        await provider.complete(0, stars: 100)

        await #expect(throws: CancellationError.self) {
            try await first.value
        }

        let retry = Task {
            try await cache.fetchRepository(owner: "apple", name: "swift")
        }
        await provider.waitUntilRequested(1)
        await provider.complete(1, stars: 200)

        let result = try await retry.value
        #expect(result.stars == 200)
        #expect(await provider.fetchCount == 2)
    }

    @Test
    func cancellationReachesWrappedProvider() async {
        let provider = ControlledCacheProvider(cooperatesWithCancellation: true)
        let cache = CachingRepositoryProvider(wrapping: provider)
        let task = Task {
            try await cache.fetchRepository(owner: "apple", name: "swift")
        }
        await provider.waitUntilRequested(0)
        task.cancel()

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
        #expect(await provider.observedCancellation)
    }

    @Test
    func alreadyCancelledCallerDoesNotReceiveCachedRepository() async throws {
        let repository = GitHubRepository(
            id: 1, name: "swift", fullName: "apple/swift", stars: 100
        )
        let provider = CountingRepositoryProvider(repository: repository)
        let cache = CachingRepositoryProvider(wrapping: provider)
        _ = try await cache.fetchRepository(owner: "apple", name: "swift")

        // This task inherits MainActor, so it cannot start before cancel()
        // while the test still holds the actor.
        let task = Task {
            try await cache.fetchRepository(owner: "apple", name: "swift")
        }
        task.cancel()

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
        #expect(await provider.fetchCount == 1)
    }
}

private actor ControlledCacheProvider: GitHubRepositoryProviding {
    private let cooperatesWithCancellation: Bool
    private var pending: [Int: CheckedContinuation<GitHubRepository, Error>] = [:]
    private var waiters: [Int: [CheckedContinuation<Void, Never>]] = [:]
    private(set) var fetchCount = 0
    private(set) var observedCancellation = false

    init(cooperatesWithCancellation: Bool = false) {
        self.cooperatesWithCancellation = cooperatesWithCancellation
    }

    func fetchRepository(owner: String, name: String) async throws -> GitHubRepository {
        let requestID = fetchCount
        fetchCount += 1

        if cooperatesWithCancellation {
            notifyWaiters(for: requestID)
            do {
                // Suspension only: the test cancels after registration.
                try await Task.sleep(for: .seconds(60))
            } catch is CancellationError {
                observedCancellation = true
                throw CancellationError()
            }
            preconditionFailure("Expected the test to cancel the request")
        }

        // Deliberately return even after cancellation to test the cache's guard.
        return try await withCheckedThrowingContinuation { continuation in
            precondition(pending[requestID] == nil)
            pending[requestID] = continuation
            notifyWaiters(for: requestID)
        }
    }

    func waitUntilRequested(_ requestID: Int) async {
        if requestID < fetchCount {
            return
        }
        await withCheckedContinuation { continuation in
            waiters[requestID, default: []].append(continuation)
        }
    }

    func complete(_ requestID: Int, stars: Int) {
        guard let continuation = pending.removeValue(forKey: requestID) else {
            preconditionFailure("No pending request: \(requestID)")
        }
        continuation.resume(returning: GitHubRepository(
            id: 1, name: "swift", fullName: "apple/swift", stars: stars
        ))
    }

    private func notifyWaiters(for requestID: Int) {
        for waiter in waiters.removeValue(forKey: requestID) ?? [] {
            waiter.resume()
        }
    }

    func searchRepositories(query: String) async throws -> GitHubSearchResponse {
        GitHubSearchResponse(totalCount: 0, items: [])
    }
}
