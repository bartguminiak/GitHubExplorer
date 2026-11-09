import SwiftUI

struct RepositoryDetailView: View {

    init(
        owner: String,
        name: String,
        repositoryProvider: any GitHubRepositoryProviding
    ) {
        self.owner = owner
        self.name = name

        _viewModel = State(
            initialValue: RepositoryViewModel(
                repositoryProvider: repositoryProvider
            )
        )
    }
    
    let owner: String
    let name: String

    @State private var viewModel: RepositoryViewModel

    @State private var retryAttempt = 0

    private struct RequestID: Equatable {
        let owner: String
        let name: String
        let attempt: Int
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading repository...")
            } else if let failure = viewModel.failure {
                ContentUnavailableView {
                    Label("Failed to load repository", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(failure.message)
                } actions: {
                    if failure.allowsRetry {
                        Button("Retry") {
                            retryAttempt += 1
                        }
                        .accessibilityIdentifier("detailRetry")
                    }
                }
            } else if let repository = viewModel.repository {
                List {
                    LabeledContent("Name", value: repository.name)
                    LabeledContent("Full name", value: repository.fullName)
                    LabeledContent(
                        "Stars",
                        value: repository.stars.formatted()
                    )
                }
            } else {
                ContentUnavailableView(
                    "No repository",
                    systemImage: "tray"
                )
            }
        }
        .navigationTitle(name)
        .task(id: RequestID(owner: owner, name: name, attempt: retryAttempt)) {
            await viewModel.loadRepository(
                owner: owner,
                name: name
            )
        }
    }
    
}

#if DEBUG
private nonisolated struct PreviewRepositoryProvider: GitHubRepositoryProviding {
    enum State: Sendable {
        case loading
        case success
        case failure
    }

    let state: State

    func fetchRepository(owner: String, name: String) async throws -> GitHubRepository {
        switch state {
        case .loading:
            while true {
                try await Task.sleep(for: .seconds(60))
            }
            return .init(id: 0, name: "", fullName: "", stars: 0)
        case .success:
            return GitHubRepository(
                id: 1,
                name: name,
                fullName: "\(owner)/\(name)",
                stars: 68_000
            )
        case .failure:
            throw URLError(.notConnectedToInternet)
        }
    }

    func searchRepositories(query: String) async throws -> GitHubSearchResponse {
        let repository = try await fetchRepository(owner: "swiftlang", name: "swift")
        return GitHubSearchResponse(totalCount: 1, items: [repository])
    }
}

#Preview("Loading") {
    NavigationStack {
        RepositoryDetailView(
            owner: "swiftlang",
            name: "swift",
            repositoryProvider: PreviewRepositoryProvider(state: .loading)
        )
    }
}

#Preview("Success") {
    NavigationStack {
        RepositoryDetailView(
            owner: "swiftlang",
            name: "swift",
            repositoryProvider: PreviewRepositoryProvider(state: .success)
        )
    }
}

#Preview("Error") {
    NavigationStack {
        RepositoryDetailView(
            owner: "swiftlang",
            name: "swift",
            repositoryProvider: PreviewRepositoryProvider(state: .failure)
        )
    }
}
#endif
