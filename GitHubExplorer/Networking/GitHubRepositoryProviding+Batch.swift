import Foundation

extension GitHubRepositoryProviding {

    func fetchRepositories(
        _ identifiers: [RepositoryIdentifier]
    ) async throws -> [GitHubRepository] {

        try await withThrowingTaskGroup(
            of: GitHubRepository.self
        ) { group in

            for identifier in identifiers {
                group.addTask {
                    try await self.fetchRepository(
                        owner: identifier.owner,
                        name: identifier.name
                    )
                }
            }

            var repositories: [GitHubRepository] = []

            for try await repository in group {
                repositories.append(repository)
            }

            return repositories
        }
    }

}
