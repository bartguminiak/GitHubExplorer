import Foundation
import Testing
@testable import GitHubExplorer

struct GitHubExplorerTests {

    @Test
    func decodesRepositoryFromJSON() throws {
        let json = """
        {
            "id": 123,
            "name": "swift",
            "full_name": "apple/swift",
            "stargazers_count": 70000
        }
        """.data(using: .utf8)!
        
        let repository = try JSONDecoder().decode(
            GitHubRepository.self,
            from: json
        )
        
        #expect(repository.id == 123)
        #expect(repository.name == "swift")
        #expect(repository.fullName == "apple/swift")
        #expect(repository.stars == 70000)
    }

}
