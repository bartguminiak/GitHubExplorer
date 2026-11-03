import SwiftUI

struct RepositoryListView: View {
    @State private var viewModel = RepositoryViewModel(
        repositoryProvider: GitHubAPIClient()
    )

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading repository...")
                } else if let repository = viewModel.repository {
                    repositoryContent(repository)
                } else if let errorMessage = viewModel.errorMessage {
                    ContentUnavailableView {
                        Label("Something went wrong", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(errorMessage)
                    } actions: {
                        Button("Retry") {
                            Task {
                                await viewModel.loadRepository()
                            }
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "No repository",
                        systemImage: "tray"
                    )
                }
            }
            .navigationTitle("GitHub Explorer")
            .task {
                await viewModel.loadRepository()
            }
        }
    }

    private func repositoryContent(
        _ repository: GitHubRepository
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(repository.fullName)
                .font(.title2.bold())

            Label(
                repository.stars.formatted(),
                systemImage: "star.fill"
            )
            .foregroundStyle(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}
