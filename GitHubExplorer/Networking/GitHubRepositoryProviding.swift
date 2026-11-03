import Foundation

nonisolated protocol GitHubRepositoryProviding: Sendable {
    func fetchRepository(
        owner: String,
        name: String
    ) async throws -> GitHubRepository
}

extension GitHubAPIClient: GitHubRepositoryProviding {}
