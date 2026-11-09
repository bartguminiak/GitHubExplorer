import SwiftUI

struct SearchView: View {

    init(repositoryProvider: any GitHubRepositoryProviding) {
        _viewModel = State(
            initialValue: SearchViewModel(
                repositoryProvider: repositoryProvider
            )
        )

        self.repositoryProvider = repositoryProvider
    }
    
    @State private var viewModel: SearchViewModel
    
    private let repositoryProvider: any GitHubRepositoryProviding

    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Searching...")
                } else if let errorMessage = viewModel.errorMessage {
                    ContentUnavailableView(
                        "Search failed",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                } else if viewModel.repositories.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    VStack {
                        SearchResultsHeader(totalCount: viewModel.totalCount)
                        List(viewModel.repositories) { repository in
                            NavigationLink {
                                RepositoryDetailView(
                                    owner: String(repository.fullName.split(separator: "/")[0]),
                                    name: repository.name,
                                    repositoryProvider: repositoryProvider
                                )
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(repository.fullName)
                                        .font(.headline)

                                    Label(
                                        repository.stars.formatted(),
                                        systemImage: "star"
                                    )
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("GitHub Explorer")
            .searchable(
                text: $searchText,
                prompt: "Search repositories"
            )
            .task(id: searchText) {
                let query = searchText.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                
                if query.isEmpty {
                    await viewModel.search(query: "")
                    return
                }
                
                do {
                    try await Task.sleep(for: .milliseconds(350))
                    try Task.checkCancellation()

                    await viewModel.search(query: searchText)
                } catch is CancellationError {
                    return
                } catch {
                    return
                }
            }
        }
    }
}
#if DEBUG
private extension SearchView {
    init(previewState: PreviewSearchRepositoryProvider.State) {
        self.init(repositoryProvider: PreviewSearchRepositoryProvider(state: previewState))
        _searchText = State(initialValue: "swift")
    }
}

private nonisolated struct PreviewSearchRepositoryProvider: GitHubRepositoryProviding {
    enum State: Sendable {
        case loading
        case success
        case failure
    }

    let state: State

    private static let repositories = [
        GitHubRepository(id: 1, name: "swift", fullName: "swiftlang/swift", stars: 68_000),
        GitHubRepository(id: 2, name: "swift-testing", fullName: "swiftlang/swift-testing", stars: 2_500),
        GitHubRepository(id: 3, name: "swift-syntax", fullName: "swiftlang/swift-syntax", stars: 3_500)
    ]

    func fetchRepository(owner: String, name: String) async throws -> GitHubRepository {
        guard let repository = Self.repositories.first(where: {
            $0.fullName == "\(owner)/\(name)"
        }) else {
            throw GitHubAPIError.httpError(statusCode: 404)
        }
        return repository
    }

    func searchRepositories(query: String) async throws -> GitHubSearchResponse {
        switch state {
        case .loading:
            while true {
                try await Task.sleep(for: .seconds(60))
            }
            return .init(totalCount: 0, items: [])
        case .success:
            let items = Self.repositories.filter {
                $0.fullName.localizedCaseInsensitiveContains(query)
            }
            return GitHubSearchResponse(totalCount: items.count, items: items)
        case .failure:
            throw URLError(.notConnectedToInternet)
        }
    }
}

#Preview("Loading") {
    SearchView(previewState: .loading)
}

#Preview("Success") {
    SearchView(previewState: .success)
}

#Preview("Error") {
    SearchView(previewState: .failure)
}
#endif
