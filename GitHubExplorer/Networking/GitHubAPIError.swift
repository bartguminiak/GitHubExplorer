nonisolated enum GitHubAPIError: Error, Equatable {
    case invalidResponse
    case httpError(statusCode: Int)
}
