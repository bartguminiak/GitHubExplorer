import Foundation
import Observation

@MainActor
@Observable
final class SearchViewModel {

    private(set) var repositories: [GitHubRepository] = []
    private(set) var totalCount = 0
    private(set) var isLoading = false
    private(set) var failure: RepositoryFailure?

    @ObservationIgnored
    private let repositoryProvider: any GitHubRepositoryProviding
    
    @ObservationIgnored
    private var latestRequestID: UUID?
    
    init(repositoryProvider: any GitHubRepositoryProviding) {
        self.repositoryProvider = repositoryProvider
    }

    func search(query: String) async {
        let requestID = UUID()
        latestRequestID = requestID
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            repositories = []
            totalCount = 0
            failure = nil
            isLoading = false
            return
        }

        isLoading = true
        failure = nil

        defer {
            if latestRequestID == requestID {
                isLoading = false
            }
        }

        do {
            let result = try await repositoryProvider
                .searchRepositories(query: query)
            
            try Task.checkCancellation()
            
            guard latestRequestID == requestID else {
                return
            }
            
            repositories = result.items
            totalCount = result.totalCount
        } catch is CancellationError {
            return
        } catch {
            guard latestRequestID == requestID else {
                return
            }
            
            if Task.isCancelled {
                return
            }
            
            failure = RepositoryFailure(error: error, isDetail: false)
        }
    }
    
}
