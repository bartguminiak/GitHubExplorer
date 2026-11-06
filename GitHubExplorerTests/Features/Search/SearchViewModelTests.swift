import Foundation
import Testing
@testable import GitHubExplorer

nonisolated struct MockSearchRepositoryProvider: GitHubRepositoryProviding {

    let result: Result<[GitHubRepository], Error>

    func searchRepositories(
        query: String
    ) async throws -> [GitHubRepository] {
        try result.get()
    }

    func fetchRepository(
        owner: String,
        name: String
    ) async throws -> GitHubRepository {
        throw GitHubAPIError.invalidResponse
    }
}

@MainActor
struct SearchViewModelTests {

    @Test
    func searchReturnsRepositories() async {
        let repository = GitHubRepository(
            id: 1,
            name: "swift",
            fullName: "apple/swift",
            stars: 70000
        )

        let provider = MockSearchRepositoryProvider(
            result: .success([repository])
        )

        let viewModel = SearchViewModel(
            repositoryProvider: provider
        )

        await viewModel.search(query: "swift")

        #expect(viewModel.repositories.count == 1)
        #expect(viewModel.repositories.first?.name == "swift")
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func searchFailureSetsErrorMessage() async {
        let provider = MockSearchRepositoryProvider(
            result: .failure(GitHubAPIError.invalidResponse)
        )

        let viewModel = SearchViewModel(
            repositoryProvider: provider
        )

        await viewModel.search(query: "swift")

        #expect(viewModel.repositories.isEmpty)
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.isLoading == false)
    }

    @Test
    func emptyQueryClearsResults() async {
        let repository = GitHubRepository(
            id: 1,
            name: "swift",
            fullName: "apple/swift",
            stars: 70000
        )

        let provider = MockSearchRepositoryProvider(
            result: .success([repository])
        )

        let viewModel = SearchViewModel(
            repositoryProvider: provider
        )

        await viewModel.search(query: "swift")
        await viewModel.search(query: "   ")

        #expect(viewModel.repositories.isEmpty)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.isLoading == false)
    }
    
    @Test
    func olderSearchResponseDoesNotOverwriteNewerResults() async {
        let provider = ControlledSearchRepositoryProvider()
        let viewModel = SearchViewModel(
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
            fullName: "example/swiftui",
            stars: 200
        )

        let firstTask = Task {
            await viewModel.search(query: "swift")
        }

        await provider.waitUntilRequested("swift")

        let secondTask = Task {
            await viewModel.search(query: "swiftui")
        }

        await provider.waitUntilRequested("swiftui")

        await provider.complete(
            query: "swiftui",
            with: [newRepository]
        )

        await secondTask.value

        #expect(viewModel.repositories.first?.id == 2)

        await provider.complete(
            query: "swift",
            with: [oldRepository]
        )

        await firstTask.value

        #expect(viewModel.repositories.first?.id == 2)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
    }
    
    @Test
    func olderSearchDoesNotStopNewerLoading() async {
        let provider = ControlledSearchRepositoryProvider()
        let viewModel = SearchViewModel(
            repositoryProvider: provider
        )

        let firstTask = Task {
            await viewModel.search(query: "swift")
        }

        await provider.waitUntilRequested("swift")

        let secondTask = Task {
            await viewModel.search(query: "swiftui")
        }

        await provider.waitUntilRequested("swiftui")

        await provider.complete(
            query: "swift",
            with: []
        )

        await firstTask.value

        #expect(viewModel.isLoading == true)

        await provider.complete(
            query: "swiftui",
            with: []
        )

        await secondTask.value

        #expect(viewModel.isLoading == false)
    }
    
    @Test
    func cancelledSearchDoesNotDisplayError() async {
        let provider = ControlledSearchRepositoryProvider()
        let viewModel = SearchViewModel(
            repositoryProvider: provider
        )

        let task = Task {
            await viewModel.search(query: "swift")
        }

        await provider.waitUntilRequested("swift")

        task.cancel()

        await provider.fail(
            query: "swift",
            with: URLError(.cancelled)
        )

        await task.value

        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.isLoading == false)
    }
    
}
