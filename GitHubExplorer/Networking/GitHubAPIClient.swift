
import Foundation

nonisolated struct GitHubAPIClient: Sendable {
    private let httpClient: any HTTPClient

    init(httpClient: any HTTPClient = URLSession.shared) {
        self.httpClient = httpClient
    }

    func fetchRepository(
        owner: String,
        name: String
    ) async throws -> GitHubRepository {
        let url = URL(string: "https://api.github.com")!
            .appending(path: "repos")
            .appending(path: owner)
            .appending(path: name)

        let request = URLRequest(url: url)

        let (data, response) = try await httpClient.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubAPIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw GitHubAPIError.httpError(
                statusCode: httpResponse.statusCode
            )
        }

        return try JSONDecoder().decode(
            GitHubRepository.self,
            from: data
        )
    }
}
