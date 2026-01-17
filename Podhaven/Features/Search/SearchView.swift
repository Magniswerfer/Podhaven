import SwiftUI

struct SearchView: View {
    @Environment(SyncService.self) private var syncService
    
    @State private var searchText = ""
    @State private var searchResults: [ITunesSearchResult] = []
    @State private var isSearching = false
    @State private var hasSearched = false
    @State private var searchError: String?
    
    private let searchService = ITunesSearchService()
    
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
            .onChange(of: searchText) { _, newValue in
                // Debounced search as user types
                if !newValue.isEmpty && !newValue.hasPrefix("http") {
                    Task {
                        try? await Task.sleep(for: .milliseconds(300))
                        if searchText == newValue {
                            await performSearch()
                        }
                    }
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
            if let error = searchError {
                Text(error)
            } else {
                Text("No podcasts found for \"\(searchText)\"")
            }
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
                        .padding()
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
            
            ForEach(searchResults) { result in
                SearchResultRow(result: result)
            }
        }
        .listStyle(.plain)
    }
    
    private func performSearch() async {
        guard !searchText.isEmpty else { return }
        
        isSearching = true
        hasSearched = true
        searchError = nil
        
        defer { isSearching = false }
        
        // If it looks like a URL, try to subscribe directly
        if searchText.hasPrefix("http://") || searchText.hasPrefix("https://") {
            await subscribeToURL()
            return
        }
        
        // Search using iTunes API
        do {
            let results = try await searchService.search(query: searchText)
            searchResults = results.compactMap { $0.toITunesSearchResult() }
        } catch {
            searchError = error.localizedDescription
            searchResults = []
        }
    }
    
    private func subscribeToURL() async {
        do {
            _ = try await syncService.subscribe(to: searchText)
            searchText = ""
            hasSearched = false
            searchResults = []
        } catch {
            searchError = error.localizedDescription
        }
    }
}

// MARK: - Search Result

struct ITunesSearchResult: Identifiable {
    let id: String
    let title: String
    let author: String?
    let artworkURL: String?
    let feedURL: String
    let genre: String?
    let episodeCount: Int?
    
    init(
        id: String,
        title: String,
        author: String?,
        artworkURL: String?,
        feedURL: String,
        genre: String? = nil,
        episodeCount: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.artworkURL = artworkURL
        self.feedURL = feedURL
        self.genre = genre
        self.episodeCount = episodeCount
    }
}

struct SearchResultRow: View {
    let result: ITunesSearchResult
    
    @Environment(SyncService.self) private var syncService
    @State private var isSubscribing = false
    @State private var didSubscribe = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Artwork
            AsyncImage(url: URL(string: result.artworkURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.2))
                    .overlay {
                        Image(systemName: "waveform")
                            .foregroundStyle(.secondary)
                    }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(.headline)
                    .lineLimit(2)
                
                if let author = result.author {
                    Text(author)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                HStack(spacing: 6) {
                    if let genre = result.genre {
                        Text(genre)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    if let count = result.episodeCount, count > 0 {
                        if result.genre != nil {
                            Text("•")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text("\(count) episodes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Subscribe button
            Button {
                Task {
                    isSubscribing = true
                    do {
                        _ = try await syncService.subscribe(to: result.feedURL)
                        didSubscribe = true
                    } catch {
                        // Handle error silently for now
                    }
                    isSubscribing = false
                }
            } label: {
                if isSubscribing {
                    ProgressView()
                        .frame(width: 28, height: 28)
                } else if didSubscribe {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                }
            }
            .buttonStyle(.plain)
            .disabled(didSubscribe)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SearchView()
        .environment(SyncService.preview)
}
