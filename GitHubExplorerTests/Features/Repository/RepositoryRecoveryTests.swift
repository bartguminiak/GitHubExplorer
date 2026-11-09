import Foundation
import Testing
@testable import GitHubExplorer

@MainActor
struct RepositoryRecoveryTests {
    @Test(arguments: [false, true])
    func retryRecoversAndReplacesFailure(isDetail: Bool) async {
        let provider = RecoveryProvider()
        let search = SearchViewModel(repositoryProvider: provider)
        let detail = RepositoryViewModel(repositoryProvider: provider)
        func load() async {
            if isDetail { await detail.loadRepository(owner: "apple", name: "swift") }
            else { await search.search(query: "swift") }
        }
        var failure: RepositoryFailure? { isDetail ? detail.failure : search.failure }
        var loading: Bool { isDetail ? detail.isLoading : search.isLoading }

        let first = Task { await load() }
        await provider.wait(0)
        await provider.finish(0, error: URLError(.notConnectedToInternet))
        await first.value
        #expect(failure == .offline)

        let retry = Task { await load() }
        await provider.wait(1)
        #expect(failure == nil)
        #expect(loading)
        await provider.finish(1, error: URLError(.timedOut))
        await retry.value
        #expect(failure == .unavailable)

        let success = Task { await load() }
        await provider.wait(2)
        await provider.finish(2)
        await success.value
        #expect(failure == nil)
        #expect(!loading)
        #expect(isDetail ? detail.repository?.id == 1 : search.repositories.first?.id == 1)
    }

    @Test(arguments: [false, true])
    func cancelledRetryStaysSilent(isDetail: Bool) async {
        let provider = RecoveryProvider()
        let search = SearchViewModel(repositoryProvider: provider)
        let detail = RepositoryViewModel(repositoryProvider: provider)
        func load() async {
            if isDetail { await detail.loadRepository(owner: "apple", name: "swift") }
            else { await search.search(query: "swift") }
        }
        let first = Task { await load() }
        await provider.wait(0)
        await provider.finish(0, error: URLError(.notConnectedToInternet))
        await first.value

        let retry = Task { await load() }
        await provider.wait(1)
        retry.cancel()
        await provider.finish(1, error: URLError(.cancelled))
        await retry.value
        #expect(isDetail ? detail.failure == nil : search.failure == nil)
        #expect(isDetail ? !detail.isLoading : !search.isLoading)
    }

    @Test(arguments: [false, true])
    func oldFailureCannotReplaceNewSuccess(isDetail: Bool) async {
        let provider = RecoveryProvider()
        let search = SearchViewModel(repositoryProvider: provider)
        let detail = RepositoryViewModel(repositoryProvider: provider)
        func load() async {
            if isDetail { await detail.loadRepository(owner: "apple", name: "swift") }
            else { await search.search(query: "swift") }
        }
        let old = Task { await load() }
        await provider.wait(0)
        let new = Task { await load() }
        await provider.wait(1)
        await provider.finish(1)
        await new.value
        await provider.finish(0, error: URLError(.timedOut))
        await old.value
        #expect(isDetail ? detail.failure == nil : search.failure == nil)
        #expect(isDetail ? detail.repository?.id == 1 : search.repositories.first?.id == 1)
    }

    @Test
    func mapsErrorsAndRetryPolicy() {
        let cases: [(any Error, RepositoryFailure)] = [
            (URLError(.notConnectedToInternet), .offline),
            (URLError(.timedOut), .unavailable),
            (GitHubAPIError.httpError(statusCode: 404), .notFound),
            (GitHubAPIError.httpError(statusCode: 429), .unavailable),
            (GitHubAPIError.httpError(statusCode: 503), .unavailable),
            (GitHubAPIError.httpError(statusCode: 403), .unavailable),
            (GitHubAPIError.invalidResponse, .unavailable),
            (DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "bad")), .unavailable),
            (URLError(.unknown), .unavailable)
        ]
        for (error, expected) in cases {
            let failure = RepositoryFailure(error: error, isDetail: true)
            #expect(failure == expected)
            #expect(failure.allowsRetry == (expected != .notFound))
            #expect(!String(localized: failure.message).isEmpty)
        }
        #expect(RepositoryFailure(error: GitHubAPIError.httpError(statusCode: 404), isDetail: false) == .unavailable)
    }
}

private actor RecoveryProvider: GitHubRepositoryProviding {
    private var count = 0
    private var pending: [Int: CheckedContinuation<Void, Error>] = [:]
    private var waiters: [Int: CheckedContinuation<Void, Never>] = [:]

    private func request() async throws {
        let id = count
        count += 1
        try await withCheckedThrowingContinuation { continuation in
            pending[id] = continuation
            waiters.removeValue(forKey: id)?.resume()
        }
    }

    func wait(_ id: Int) async {
        if pending[id] != nil { return }
        await withCheckedContinuation { waiters[id] = $0 }
    }

    func finish(_ id: Int, error: (any Error)? = nil) {
        guard let continuation = pending.removeValue(forKey: id) else {
            preconditionFailure("No pending request")
        }
        if let error { continuation.resume(throwing: error) }
        else { continuation.resume() }
    }

    func fetchRepository(owner: String, name: String) async throws -> GitHubRepository {
        try await request()
        return GitHubRepository(id: 1, name: name, fullName: "\(owner)/\(name)", stars: 100)
    }

    func searchRepositories(query: String) async throws -> GitHubSearchResponse {
        try await request()
        return GitHubSearchResponse(totalCount: 1, items: [
            GitHubRepository(id: 1, name: "swift", fullName: "apple/swift", stars: 100)
        ])
    }
}
