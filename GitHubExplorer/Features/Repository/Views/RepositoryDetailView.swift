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

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading repository...")
            } else if let errorMessage = viewModel.errorMessage {
                ContentUnavailableView(
                    "Failed to load repository",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
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
        .task(id: "\(owner)/\(name)") {
            await viewModel.loadRepository(
                owner: owner,
                name: name
            )
        }
    }
    
}
