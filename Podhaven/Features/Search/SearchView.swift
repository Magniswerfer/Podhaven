import SwiftUI

struct SearchView: View {
    @Environment(SyncService.self) private var syncService
    
    @State private var searchText = ""
    @State private var searchResults: [PodcastSearchResult] = []
    @State private var isSearching = false
    @State private var hasSearched = false
    
    var body: some View {
        NavigationStack {
            Group {
                if !hasSearched {
                    searchPrompt
                } else if searchResults.isEmpty && !isSearching {
                    noResults
                } else {
                    resultsList
                }
            }
            .navigationTitle("Search")
            .searchable(text: $searchText, prompt: "Search podcasts or enter RSS URL")
            .onSubmit(of: .search) {
                Task {
                    await performSearch()
                }
            }
        }
    }
    
    private var searchPrompt: some View {
        ContentUnavailableView {
            Label("Search Podcasts", systemImage: "magnifyingglass")
        } description: {
            Text("Search for podcasts by name or paste an RSS feed URL")
        }
    }
    
    private var noResults: some View {
        ContentUnavailableView {
            Label("No Results", systemImage: "magnifyingglass")
        } description: {
            Text("No podcasts found for \"\(searchText)\"")
        } actions: {
            if searchText.contains("http") || searchText.contains(".") {
                Button("Try as RSS URL") {
                    Task {
                        await subscribeToURL()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
    
    private var resultsList: some View {
        List {
            if isSearching {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
            
            ForEach(searchResults) { result in
                SearchResultRow(result: result)
            }
        }
    }
    
    private func performSearch() async {
        guard !searchText.isEmpty else { return }
        
        isSearching = true
        hasSearched = true
        defer { isSearching = false }
        
        // If it looks like a URL, try to subscribe directly
        if searchText.hasPrefix("http://") || searchText.hasPrefix("https://") {
            await subscribeToURL()
            return
        }
        
        // TODO: Implement podcast search using iTunes API or similar
        // For now, just clear results - this would integrate with a search API
        searchResults = []
    }
    
    private func subscribeToURL() async {
        do {
            _ = try await syncService.subscribe(to: searchText)
            searchText = ""
            hasSearched = false
        } catch {
            // Handle error
        }
    }
}

// MARK: - Search Result

struct PodcastSearchResult: Identifiable {
    let id: String
    let title: String
    let author: String?
    let artworkURL: String?
    let feedURL: String
}

struct SearchResultRow: View {
    let result: PodcastSearchResult
    
    @Environment(SyncService.self) private var syncService
    @State private var isSubscribing = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Artwork
            AsyncImage(url: URL(string: result.artworkURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.2))
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(.headline)
                
                if let author = result.author {
                    Text(author)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Subscribe button
            Button {
                Task {
                    isSubscribing = true
                    _ = try? await syncService.subscribe(to: result.feedURL)
                    isSubscribing = false
                }
            } label: {
                if isSubscribing {
                    ProgressView()
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    SearchView()
        .environment(SyncService.preview)
}
