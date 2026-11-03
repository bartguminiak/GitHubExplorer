import Testing
@testable import GitHubExplorer

@MainActor
struct RepositoryViewModelTests {

    @Test
    func loadRepositoryUpdatesState() async throws {
        let expected = GitHubRepository(
            id: 123,
            name: "swift",
            fullName: "apple/swift",
            stars: 70000
        )

        let provider = MockRepositoryProvider(
            result: .success(expected)
        )

        let viewModel = RepositoryViewModel(
            repositoryProvider: provider
        )

        await viewModel.loadRepository()

        #expect(viewModel.repository?.id == 123)
        #expect(viewModel.repository?.name == "swift")
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func loadRepositoryHandlesError() async {
        let provider = MockRepositoryProvider(
            result: .failure(
                GitHubAPIError.httpError(statusCode: 404)
            )
        )

        let viewModel = RepositoryViewModel(
            repositoryProvider: provider
        )

        await viewModel.loadRepository()

        #expect(viewModel.repository == nil)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage != nil)
    }
}
