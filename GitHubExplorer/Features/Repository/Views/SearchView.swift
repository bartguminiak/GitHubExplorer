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
