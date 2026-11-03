import Foundation
import Testing
@testable import GitHubExplorer

nonisolated struct MockHTTPClient: HTTPClient {
    let responseData: Data
    let response: URLResponse
    var validateRequest: (@Sendable (URLRequest) -> Void)? = nil
    
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        validateRequest?(request)
        return (responseData, response)
    }
}
