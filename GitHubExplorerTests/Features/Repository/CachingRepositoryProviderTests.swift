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
    ) async throws -> [GitHubRepository] {
        []
    }

}

private actor UpdatingRepositoryProvider: GitHubRepositoryProviding {
    private var count = 0

    func fetchRepository(owner: String, name: String) async throws -> GitHubRepository {
        count += 1
        return GitHubRepository(id: 1, name: name, fullName: "\(owner)/\(name)", stars: count)
    }

    func searchRepositories(query: String) async throws -> [GitHubRepository] { [] }
}
