import Foundation

actor CachingRepositoryProvider: GitHubRepositoryProviding {
    private struct CacheEntry {
        let repository: GitHubRepository
        let expiresAt: Date
    }

    private let wrapped: any GitHubRepositoryProviding
    private let cacheLifetime: TimeInterval
    private let now: @Sendable () -> Date
    private var cache: [String: CacheEntry] = [:]

    init(
        wrapping provider: any GitHubRepositoryProviding,
        cacheLifetime: TimeInterval = 60,
        now: @escaping @Sendable () -> Date = { Date.now }
    ) {
        self.wrapped = provider
        self.cacheLifetime = cacheLifetime
        self.now = now
    }

    func fetchRepository(
        owner: String,
        name: String
    ) async throws -> GitHubRepository {
        try Task.checkCancellation()

        let key = "\(owner.lowercased())/\(name.lowercased())"

        if let entry = cache[key], entry.expiresAt > now() {
            return entry.repository
        }
        cache[key] = nil

        // Concurrent misses fetch independently in their callers' tasks.
        let repository = try await wrapped.fetchRepository(owner: owner, name: name)
        try Task.checkCancellation()

        cache[key] = CacheEntry(
            repository: repository,
            expiresAt: now().addingTimeInterval(cacheLifetime)
        )
        return repository
    }

    func searchRepositories(query: String) async throws -> GitHubSearchResponse {
        try await wrapped.searchRepositories(query: query)
    }
}
