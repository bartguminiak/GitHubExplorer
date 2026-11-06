import Foundation

actor CachingRepositoryProvider: GitHubRepositoryProviding {

    private let wrapped: any GitHubRepositoryProviding

    private var cache: [String: GitHubRepository] = [:]
    private var inFlight: [String: Task<GitHubRepository, Error>] = [:]

    init(wrapping provider: any GitHubRepositoryProviding) {
        self.wrapped = provider
    }

    func fetchRepository(
        owner: String,
        name: String
    ) async throws -> GitHubRepository {
        let key = "\(owner.lowercased())/\(name.lowercased())"

        if let cached = cache[key] {
            return cached
        }

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
            cache[key] = repository
            inFlight[key] = nil
            return repository
        } catch {
            inFlight[key] = nil
            throw error
        }
    }

    func searchRepositories(
        query: String
    ) async throws -> [GitHubRepository] {
        try await wrapped.searchRepositories(query: query)
    }

}
