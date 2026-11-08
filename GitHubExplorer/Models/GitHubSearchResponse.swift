nonisolated struct GitHubSearchResponse: Decodable, Sendable {
    let totalCount: Int
    let items: [GitHubRepository]

    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case items
    }
}
