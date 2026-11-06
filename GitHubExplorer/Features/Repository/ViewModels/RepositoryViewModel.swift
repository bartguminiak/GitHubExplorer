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

    @ObservationIgnored
    private var latestRequestID: UUID?
    
    @ObservationIgnored
    private var loadTask: Task<Void, Never>?

    init(repositoryProvider: any GitHubRepositoryProviding) {
        self.repositoryProvider = repositoryProvider
    }
    
    func startLoading(name: String = "swift") {
        loadTask?.cancel()
        
        loadTask = Task {
            await loadRepository(owner: name, name: "")
        }
    }
    
    func cancelLoading() {
        loadTask?.cancel()
        loadTask = nil
    }

    func loadRepository(owner: String, name: String) async {
        let requestID = UUID()
        latestRequestID = requestID

        isLoading = true
        errorMessage = nil

        defer {
            if latestRequestID == requestID {
                isLoading = false
            }
        }

        do {
            let result = try await repositoryProvider.fetchRepository(
                owner: owner,
                name: name
            )
            
            try Task.checkCancellation()

            guard latestRequestID == requestID else {
                return
            }

            repository = result

        } catch is CancellationError {
            return

        } catch {
            guard latestRequestID == requestID else {
                return
            }

            errorMessage = error.localizedDescription
        }
    }
}
