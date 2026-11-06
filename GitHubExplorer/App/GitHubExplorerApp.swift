import SwiftUI

@main struct GitHubExplorerApp: App {
    
    private let dependencies = AppDependencies()
    
    var body: some Scene {
        WindowGroup {
            SearchView(repositoryProvider: dependencies.repositoryProvider)
        }
    }
}
