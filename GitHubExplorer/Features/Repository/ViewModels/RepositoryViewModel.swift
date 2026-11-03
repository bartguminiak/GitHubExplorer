import Foundation
import Observation

@MainActor
@Observable
final class RepositoryViewModel {
    private(set) var repository: GitHubRepository?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    @ObservationIgnored
    private let repositoryProvider: any GitHubRepositoryProviding

    init(repositoryProvider: any GitHubRepositoryProviding) {
        self.repositoryProvider = repositoryProvider
    }

    func loadRepository() async {
        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            repository = try await repositoryProvider.fetchRepository(
                owner: "apple",
                name: "swift"
            )
        } catch is CancellationError {
            // Cancellation is not a user-facing error.
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
