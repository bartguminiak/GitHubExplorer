import Testing
import Foundation
@testable import GitHubExplorer

struct GitHubClientTests {
    
    @Test
    func fetchRepositoryDecodesSuccessfulResponse() async throws {
        let json = """
        {
            "id": 123,
            "name": "swift",
            "full_name": "apple/swift",
            "stargazers_count": 70000
        }
        """.data(using: .utf8)!
        
        let url = try #require(
            URL(string: "https://api.github.com/repos/apple/swift")
        )
        
        let response = try #require(
            HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )
        )
        
        let mock = MockHTTPClient(
            responseData: json,
            response: response
        )
        
        let client = GitHubAPIClient(httpClient: mock)
        
        let repository = try await client.fetchRepository(
            owner: "apple",
            name: "swift"
        )
        
        #expect(repository.id == 123)
        #expect(repository.fullName == "apple/swift")
        #expect(repository.stars == 70000)
    }
    
    @Test
    func fetchRepositoryThrowsForHTTP404() async throws {
        let url = try #require(
            URL(string: "https://api.github.com/repos/unknown/missing")
        )
        
        let response = try #require(
            HTTPURLResponse(
                url: url,
                statusCode: 404,
                httpVersion: nil,
                headerFields: nil
            )
        )
        
        let mock = MockHTTPClient(
            responseData: Data(),
            response: response
        )
        
        let client = GitHubAPIClient(httpClient: mock)
        
        await #expect(throws: GitHubAPIError.httpError(statusCode: 404)) {
            try await client.fetchRepository(
                owner: "unknown",
                name: "missing"
            )
        }
    }
    
    @Test
    func fetchRepositoryBuildsCorrectRequest() async throws {
        let expectedURL = try #require(
            URL(string: "https://api.github.com/repos/apple/swift")
        )
        
        let response = try #require(
            HTTPURLResponse(
                url: expectedURL,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )
        )
        
        let json = """
        {
            "id": 123,
            "name": "swift",
            "full_name": "apple/swift",
            "stargazers_count": 70000
        }
        """.data(using: .utf8)!
        
        let mock = MockHTTPClient(
            responseData: json,
            response: response,
            validateRequest: { request in
                #expect(request.url == expectedURL)
                #expect(request.httpMethod == "GET")
            }
        )
        
        let client = GitHubAPIClient(httpClient: mock)
        
        _ = try await client.fetchRepository(
            owner: "apple",
            name: "swift"
        )
    }
    
    @Test
    func fetchRepositoryThrowsForInvalidJSON() async throws {
        let url = try #require(
            URL(string: "https://api.github.com/repos/apple/swift")
        )
        
        let response = try #require(
            HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )
        )
        
        let mock = MockHTTPClient(
            responseData: Data("invalid json".utf8),
            response: response
        )
        
        let client = GitHubAPIClient(httpClient: mock)
        
        await #expect(throws: DecodingError.self) {
            try await client.fetchRepository(
                owner: "apple",
                name: "swift"
            )
        }
    }
    
    @Test
    func fetchRepositoryThrowsForNonHTTPResponse() async throws {
        let url = try #require(
            URL(string: "https://api.github.com/repos/apple/swift")
        )
        
        let response = URLResponse(
            url: url,
            mimeType: nil,
            expectedContentLength: 0,
            textEncodingName: nil
        )
        
        let mock = MockHTTPClient(
            responseData: Data(),
            response: response
        )
        
        let client = GitHubAPIClient(httpClient: mock)
        
        await #expect(throws: GitHubAPIError.invalidResponse) {
            try await client.fetchRepository(
                owner: "apple",
                name: "swift"
            )
        }
    }
    
    @Test
    func searchRepositoriesReturnsDecodedItemsAndTotalCount() async throws {
        let json = """
        {
            "total_count": 42,
            "incomplete_results": false,
            "items": [
                {
                    "id": 123,
                    "name": "swift",
                    "full_name": "apple/swift",
                    "stargazers_count": 70000
                }
            ]
        }
        """.data(using: .utf8)!
        
        let response = HTTPURLResponse(
            url: URL(string: "https://api.github.com/search/repositories")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        
        let mock = MockHTTPClient(
            responseData: json,
            response: response
        )
        
        let client = GitHubAPIClient(httpClient: mock)
        
        let responseData = try await client.searchRepositories(
            query: "swift"
        )
        
        #expect(responseData.totalCount == 42)
        #expect(responseData.items.count == 1)
        #expect(responseData.items.first?.name == "swift")
        #expect(responseData.items.first?.stars == 70000)
    }
    
}
