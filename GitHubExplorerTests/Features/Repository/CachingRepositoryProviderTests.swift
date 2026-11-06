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
    ) async throws -> [GitHubRepository] {
        []
    }

}
