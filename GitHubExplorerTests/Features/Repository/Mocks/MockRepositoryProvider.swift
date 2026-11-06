import Foundation
import Testing
@testable import GitHubExplorer

nonisolated struct MockRepositoryProvider: GitHubRepositoryProviding {
    let result: Result<GitHubRepository, Error>

    func fetchRepository(
        owner: String,
        name: String
    ) async throws -> GitHubRepository {
        try result.get()
    }
    
    func searchRepositories(query: String) async throws -> [GitHubRepository] {
        []
    }
}
