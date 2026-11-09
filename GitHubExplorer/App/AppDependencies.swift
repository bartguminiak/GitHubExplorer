import Foundation

@MainActor
final class AppDependencies {
    let repositoryProvider: any GitHubRepositoryProviding

    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--test-retry-recovery") {
            repositoryProvider = RetryRecoveryProvider()
            return
        }
        #endif
        repositoryProvider = CachingRepositoryProvider(wrapping: GitHubAPIClient())
    }
}

#if DEBUG
// Deterministic UI-test fixture; never selected in release builds.
private actor RetryRecoveryProvider: GitHubRepositoryProviding {
    private var failedSearch = false
    private var failedDetail = false

    func fetchRepository(owner: String, name: String) async throws -> GitHubRepository {
        if !failedDetail {
            failedDetail = true
            throw URLError(.notConnectedToInternet)
        }
        return GitHubRepository(id: 1, name: name, fullName: "\(owner)/\(name)", stars: 100)
    }

    func searchRepositories(query: String) async throws -> GitHubSearchResponse {
        if !failedSearch {
            failedSearch = true
            throw URLError(.notConnectedToInternet)
        }
        return GitHubSearchResponse(totalCount: 1, items: [
            GitHubRepository(id: 1, name: "swift", fullName: "apple/swift", stars: 100)
        ])
    }
}
#endif
