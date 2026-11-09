import Foundation

nonisolated enum RepositoryFailure: Equatable, Sendable {
    case offline
    case notFound
    case unavailable

    init(error: any Error, isDetail: Bool) {
        switch error {
        case let error as URLError where error.code == .notConnectedToInternet:
            self = .offline
        case GitHubAPIError.httpError(statusCode: 404) where isDetail:
            self = .notFound
        default:
            self = .unavailable
        }
    }

    var allowsRetry: Bool { self != .notFound }

    var message: LocalizedStringResource {
        switch self {
        case .offline: "You appear to be offline. Check your connection and try again."
        case .notFound: "This repository could not be found."
        case .unavailable: "We couldn’t load the content. Please try again."
        }
    }
}
