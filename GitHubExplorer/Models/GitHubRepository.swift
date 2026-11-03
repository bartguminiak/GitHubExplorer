nonisolated struct GitHubRepository: Decodable, Identifiable, Sendable {
    let id: Int
    let name: String
    let fullName: String
    let stars: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case fullName = "full_name"
        case stars = "stargazers_count"
    }
}
