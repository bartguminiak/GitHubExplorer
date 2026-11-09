import Foundation

actor CachingRepositoryProvider: GitHubRepositoryProviding {

    private let wrapped: any GitHubRepositoryProviding

    private struct CacheEntry {
        let repository: GitHubRepository
        let expiresAt: Date
    }

    private let cacheLifetime: TimeInterval
    private var cache: [String: CacheEntry] = [:]
    private var inFlight: [String: Task<GitHubRepository, Error>] = [:]

    init(wrapping provider: any GitHubRepositoryProviding, cacheLifetime: TimeInterval = 60) {
        self.wrapped = provider
        self.cacheLifetime = cacheLifetime
    }

    func fetchRepository(
        owner: String,
        name: String
    ) async throws -> GitHubRepository {
        let key = "\(owner.lowercased())/\(name.lowercased())"

        if let cached = cache[key], cached.expiresAt > Date() {
            return cached.repository
        }
        cache[key] = nil

        if let existingTask = inFlight[key] {
            return try await existingTask.value
        }

        let task = Task {
            try await wrapped.fetchRepository(
                owner: owner,
                name: name
            )
        }

        inFlight[key] = task

        do {
            let repository = try await task.value
            cache[key] = CacheEntry(
                repository: repository,
                expiresAt: Date().addingTimeInterval(cacheLifetime)
            )
            inFlight[key] = nil
            return repository
        } catch {
            inFlight[key] = nil
            throw error
        }
    }

    func searchRepositories(
        query: String
    ) async throws -> GitHubSearchResponse {
        try await wrapped.searchRepositories(query: query)
    }

}
