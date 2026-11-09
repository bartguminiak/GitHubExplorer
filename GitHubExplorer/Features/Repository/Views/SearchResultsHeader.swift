import SwiftUI

/// Displays the API's total result count in a search results section header.
struct SearchResultsHeader: View {
    let totalCount: Int

    var body: some View {
        Text("Showing \(min(totalCount, 20)) of \(totalCount, format: .number) results")
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }
}

#Preview("List header") {
    NavigationStack {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("swiftlang/swift")
                        .font(.headline)
                    Label("68,500", systemImage: "star")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } header: {
                SearchResultsHeader(totalCount: 12840)
            }
        }
        .navigationTitle("GitHub Explorer")
        .searchable(text: .constant("swift"), prompt: "Search repositories")
    }
}
