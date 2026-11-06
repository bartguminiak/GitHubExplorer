import Foundation
@testable import GitHubExplorer

actor ControlledSearchRepositoryProvider: GitHubRepositoryProviding {

    private var pending: [
        String: CheckedContinuation<[GitHubRepository], Error>
    ] = [:]

    private var waiters: [
        String: [CheckedContinuation<Void, Never>]
    ] = [:]

    func searchRepositories(
        query: String
    ) async throws -> [GitHubRepository] {
        try await withCheckedThrowingContinuation { continuation in
            pending[query] = continuation

            let registeredWaiters = waiters.removeValue(
                forKey: query
            ) ?? []

            for waiter in registeredWaiters {
                waiter.resume()
            }
        }
    }

    func waitUntilRequested(_ query: String) async {
        if pending[query] != nil {
            return
        }

        await withCheckedContinuation { continuation in
            waiters[query, default: []].append(continuation)
        }
    }

    func complete(
        query: String,
        with repositories: [GitHubRepository]
    ) {
        guard let continuation = pending.removeValue(
            forKey: query
        ) else {
            preconditionFailure("No pending request: \(query)")
        }

        continuation.resume(returning: repositories)
    }

    func fail(
        query: String,
        with error: any Error
    ) {
        guard let continuation = pending.removeValue(
            forKey: query
        ) else {
            preconditionFailure("No pending request: \(query)")
        }

        continuation.resume(throwing: error)
    }

    func fetchRepository(
        owner: String,
        name: String
    ) async throws -> GitHubRepository {
        throw GitHubAPIError.invalidResponse
    }
}
