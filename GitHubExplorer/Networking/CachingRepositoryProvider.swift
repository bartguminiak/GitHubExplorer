actor CachingRepositoryProvider: GitHubRepositoryProviding {
    private let wrapped: any GitHubRepositoryProviding
    private let capacity: Int
    private var cache: [String: GitHubRepository] = [:]

    init(wrapping provider: any GitHubRepositoryProviding, capacity: Int = 50) {
        precondition(capacity > 0, "Cache capacity must be positive")
        self.wrapped = provider
        self.capacity = capacity
    }

    func fetchRepository(
        owner: String,
        name: String
    ) async throws -> GitHubRepository {
        try Task.checkCancellation()

        let key = "\(owner.lowercased())/\(name.lowercased())"
        if let repository = cache[key] {
            return repository
        }

        // Concurrent misses fetch independently in their callers' tasks.
        let repository = try await wrapped.fetchRepository(owner: owner, name: name)
        try Task.checkCancellation()

        // Session cache: evict an arbitrary entry only when adding a new key.
        // Check after awaiting because other fetches may have filled the cache.
        if cache[key] == nil, cache.count >= capacity, let evictedKey = cache.keys.first {
            cache.removeValue(forKey: evictedKey)
        }
        cache[key] = repository
        return repository
    }

    func searchRepositories(query: String) async throws -> GitHubSearchResponse {
        try await wrapped.searchRepositories(query: query)
    }
}
