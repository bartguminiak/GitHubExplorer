import Foundation
@testable import GitHubExplorer

actor ControlledRepositoryProvider: GitHubRepositoryProviding {
    func searchRepositories(query: String) async throws -> [GitHubExplorer.GitHubRepository] {
        []
    }
    

    private var pending: [
        String: CheckedContinuation<GitHubRepository, Error>
    ] = [:]

    private var registrationWaiters: [
        String: [CheckedContinuation<Void, Never>]
    ] = [:]

    func fetchRepository(
        owner: String,
        name: String
    ) async throws -> GitHubRepository {
        try await withCheckedThrowingContinuation { continuation in
            pending[name] = continuation

            let waiters = registrationWaiters.removeValue(
                forKey: name
            ) ?? []

            for waiter in waiters {
                waiter.resume()
            }
        }
    }

    func waitUntilRequested(_ name: String) async {
        if pending[name] != nil {
            return
        }

        await withCheckedContinuation { continuation in
            registrationWaiters[name, default: []].append(
                continuation
            )
        }
    }

    func complete(
        name: String,
        with repository: GitHubRepository
    ) {
        guard let continuation = pending.removeValue(
            forKey: name
        ) else {
            preconditionFailure("No pending request: \(name)")
        }

        continuation.resume(returning: repository)
    }
}
