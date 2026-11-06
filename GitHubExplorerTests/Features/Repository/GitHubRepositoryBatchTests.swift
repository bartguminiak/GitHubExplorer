import Testing
@testable import GitHubExplorer

@MainActor
struct GitHubRepositoryBatchTests {

    @Test
    func fetchesMultipleRepositories() async throws {
        let provider = CountingRepositoryProvider(
            repository: GitHubRepository(
                id: 1,
                name: "swift",
                fullName: "apple/swift",
                stars: 100
            )
        )

        let identifiers = [
            RepositoryIdentifier(owner: "apple", name: "swift"),
            RepositoryIdentifier(owner: "apple", name: "swift-nio")
        ]

        let repositories = try await provider.fetchRepositories(
            identifiers
        )

        #expect(repositories.count == 2)

        let count = await provider.fetchCount
        #expect(count == 2)
    }

}
