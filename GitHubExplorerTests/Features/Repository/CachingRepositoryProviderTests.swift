import Foundation
import Testing
@testable import GitHubExplorer

@MainActor
struct CachingRepositoryProviderTests {

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
    private(set) var requests: [RepositoryIdentifier] = []

    init(cooperatesWithCancellation: Bool = false) {
        self.cooperatesWithCancellation = cooperatesWithCancellation
    }

    func fetchRepository(owner: String, name: String) async throws -> GitHubRepository {
        let requestID = fetchCount
        fetchCount += 1
        requests.append(RepositoryIdentifier(owner: owner, name: name))

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
            id: requestID, name: requests[requestID].name,
            fullName: "\(requests[requestID].owner)/\(requests[requestID].name)", stars: stars
        ))
    }

    func fail(_ requestID: Int, with error: any Error) {
        guard let continuation = pending.removeValue(forKey: requestID) else {
            preconditionFailure("No pending request: \(requestID)")
        }
        continuation.resume(throwing: error)
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

extension CachingRepositoryProviderTests {
    @Test
    func cacheKeysIgnoreCase() async throws {
        let provider = UpdatingRepositoryProvider()
        let cache = CachingRepositoryProvider(wrapping: provider)
        let first = try await cache.fetchRepository(owner: "Apple", name: "Swift")
        let second = try await cache.fetchRepository(owner: "apple", name: "swift")
        #expect(first.stars == second.stars)
        #expect(second.fullName == "Apple/Swift")
    }

    @Test
    func distinctOwnersAndNamesHaveSeparateEntries() async throws {
        let provider = UpdatingRepositoryProvider()
        let cache = CachingRepositoryProvider(wrapping: provider)
        let identifiers = [
            RepositoryIdentifier(owner: "apple", name: "swift"),
            RepositoryIdentifier(owner: "other", name: "swift"),
            RepositoryIdentifier(owner: "apple", name: "other")
        ]
        for (index, identifier) in identifiers.enumerated() {
            let result = try await cache.fetchRepository(owner: identifier.owner, name: identifier.name)
            #expect(result.fullName == "\(identifier.owner)/\(identifier.name)")
            #expect(result.stars == index + 1)
        }
        for (index, identifier) in identifiers.enumerated() {
            let result = try await cache.fetchRepository(owner: identifier.owner, name: identifier.name)
            #expect(result.stars == index + 1)
        }
    }

    @Test
    func failureAllowsRetryAndSuccessfulResultIsCached() async throws {
        let provider = ControlledCacheProvider()
        let cache = CachingRepositoryProvider(wrapping: provider)
        let first = Task {
            try await cache.fetchRepository(owner: "apple", name: "swift")
        }
        await provider.waitUntilRequested(0)
        await provider.fail(0, with: GitHubAPIError.httpError(statusCode: 503))
        await #expect(throws: GitHubAPIError.httpError(statusCode: 503)) {
            try await first.value
        }

        let retry = Task {
            try await cache.fetchRepository(owner: "apple", name: "swift")
        }
        await provider.waitUntilRequested(1)
        await provider.complete(1, stars: 200)
        let result = try await retry.value
        let cached = try await cache.fetchRepository(owner: "apple", name: "swift")
        #expect(cached.stars == result.stars)
        #expect(await provider.fetchCount == 2)
        let requests = await provider.requests
        #expect(requests == [
            RepositoryIdentifier(owner: "apple", name: "swift"),
            RepositoryIdentifier(owner: "apple", name: "swift")
        ])
    }

    @Test
    func lastSuccessfulCompletionWins() async throws {
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

        await provider.complete(1, stars: 200)
        #expect(try await second.value.stars == 200)
        await provider.complete(0, stars: 100)
        #expect(try await first.value.stars == 100)

        let cached = try await cache.fetchRepository(owner: "apple", name: "swift")
        #expect(cached.stars == 100)
        #expect(await provider.fetchCount == 2)
    }

    @Test
    func searchForwardsQueryAndBypassesDetailCache() async throws {
        let provider = RecordingSearchProvider()
        let cache = CachingRepositoryProvider(wrapping: provider)
        let first = try await cache.searchRepositories(query: " swift language:swift ")
        let second = try await cache.searchRepositories(query: " swift language:swift ")
        #expect(first.totalCount == 1)
        #expect(second.totalCount == 2)
        #expect(second.items.first?.fullName == "apple/swift")

        let detail = try await cache.fetchRepository(owner: "apple", name: "swift")
        #expect(detail.stars == 300)
        #expect(await provider.detailFetchCount == 1)
        #expect(await provider.queries == [" swift language:swift ", " swift language:swift "])
    }
}

private actor RecordingSearchProvider: GitHubRepositoryProviding {
    private(set) var queries: [String] = []
    private(set) var detailFetchCount = 0

    func fetchRepository(owner: String, name: String) async throws -> GitHubRepository {
        detailFetchCount += 1
        return GitHubRepository(id: 1, name: name, fullName: "\(owner)/\(name)", stars: 300)
    }

    func searchRepositories(query: String) async throws -> GitHubSearchResponse {
        queries.append(query)
        return GitHubSearchResponse(
            totalCount: queries.count,
            items: [GitHubRepository(id: 1, name: "swift", fullName: "apple/swift", stars: 100)]
        )
    }
}

extension CachingRepositoryProviderTests {
    @Test
    func evictedRepositoryIsFetchedAgain() async throws {
        let provider = UpdatingRepositoryProvider()
        let cache = CachingRepositoryProvider(wrapping: provider, capacity: 1)

        let first = try await cache.fetchRepository(owner: "apple", name: "swift")
        let second = try await cache.fetchRepository(owner: "apple", name: "swiftui")
        let cached = try await cache.fetchRepository(owner: "apple", name: "swiftui")
        #expect(cached.stars == second.stars)

        let refetched = try await cache.fetchRepository(owner: "apple", name: "swift")
        #expect(first.stars == 1)
        #expect(refetched.stars == 3)
    }

    @Test
    func concurrentCompletionsRespectCapacity() async throws {
        let provider = ControlledCacheProvider()
        let cache = CachingRepositoryProvider(wrapping: provider, capacity: 1)
        let first = Task {
            try await cache.fetchRepository(owner: "apple", name: "swift")
        }
        await provider.waitUntilRequested(0)
        let second = Task {
            try await cache.fetchRepository(owner: "apple", name: "swiftui")
        }
        await provider.waitUntilRequested(1)

        await provider.complete(0, stars: 100)
        _ = try await first.value
        await provider.complete(1, stars: 200)
        _ = try await second.value

        let cached = try await cache.fetchRepository(owner: "apple", name: "swiftui")
        #expect(cached.stars == 200)
        #expect(await provider.fetchCount == 2)

        let refetch = Task {
            try await cache.fetchRepository(owner: "apple", name: "swift")
        }
        await provider.waitUntilRequested(2)
        await provider.complete(2, stars: 300)
        #expect(try await refetch.value.stars == 300)
        #expect(await provider.fetchCount == 3)
    }
}
