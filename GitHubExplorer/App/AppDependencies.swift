import Foundation

@MainActor
final class AppDependencies {

    let repositoryProvider: any GitHubRepositoryProviding

    init() {
        repositoryProvider = CachingRepositoryProvider(
            wrapping: GitHubAPIClient()
        )
    }

}
