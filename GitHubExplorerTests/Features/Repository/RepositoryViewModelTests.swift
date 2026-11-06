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
    
    @Test
    func olderResponseShouldNotOverwriteNewerResponse() async {
        let provider = ControlledRepositoryProvider()
        let viewModel = RepositoryViewModel(
            repositoryProvider: provider
        )
        
        let oldRepository = GitHubRepository(
            id: 1,
            name: "swift",
            fullName: "apple/swift",
            stars: 100
        )
        
        let newRepository = GitHubRepository(
            id: 2,
            name: "swiftui",
            fullName: "apple/swiftui",
            stars: 200
        )
        
        let firstTask = Task {
            await viewModel.loadRepository(name: "swift")
        }

        await provider.waitUntilRequested("swift")

        let secondTask = Task {
            await viewModel.loadRepository(name: "swiftui")
        }

        await provider.waitUntilRequested("swiftui")

        await provider.complete(
            name: "swiftui",
            with: newRepository
        )

        await secondTask.value

        await provider.complete(
            name: "swift",
            with: oldRepository
        )

        await firstTask.value

        #expect(viewModel.repository?.id == newRepository.id)
    }
}
