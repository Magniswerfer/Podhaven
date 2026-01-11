import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SyncService.self) private var syncService
    
    @Query(filter: #Predicate<Podcast> { $0.isSubscribed }, sort: \Podcast.title)
    private var podcasts: [Podcast]
    
    @State private var showingAddPodcast = false
    @State private var isRefreshing = false
    
    var body: some View {
        NavigationStack {
            Group {
                if podcasts.isEmpty {
                    emptyState
                } else {
                    podcastGrid
                }
            }
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddPodcast = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    if syncService.isSyncing {
                        ProgressView()
                    } else {
                        Button {
                            Task {
                                try? await syncService.performSync()
                            }
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddPodcast) {
                AddPodcastView()
            }
            .refreshable {
                await refreshAllPodcasts()
            }
        }
    }
    
    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Podcasts", systemImage: "waveform")
        } description: {
            Text("Add podcasts to start listening")
        } actions: {
            Button("Add Podcast") {
                showingAddPodcast = true
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    private var podcastGrid: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 150, maximum: 180), spacing: 16)
            ], spacing: 16) {
                ForEach(podcasts) { podcast in
                    NavigationLink(value: podcast) {
                        PodcastGridItem(podcast: podcast)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .navigationDestination(for: Podcast.self) { podcast in
            PodcastDetailView(podcast: podcast)
        }
    }
    
    private func refreshAllPodcasts() async {
        isRefreshing = true
        defer { isRefreshing = false }
        
        for podcast in podcasts {
            try? await syncService.refreshPodcast(podcast)
        }
    }
}

// MARK: - Podcast Grid Item

struct PodcastGridItem: View {
    let podcast: Podcast
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Artwork
            AsyncImage(url: URL(string: podcast.artworkURL ?? "")) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(1, contentMode: .fill)
                case .failure:
                    artworkPlaceholder
                case .empty:
                    artworkPlaceholder
                        .overlay {
                            ProgressView()
                        }
                @unknown default:
                    artworkPlaceholder
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            
            // Title
            Text(podcast.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            // Unplayed count
            if podcast.unplayedCount > 0 {
                Text("\(podcast.unplayedCount) unplayed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var artworkPlaceholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.secondary.opacity(0.2))
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                Image(systemName: "waveform")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            }
    }
}

#Preview {
    LibraryView()
        .modelContainer(for: Podcast.self, inMemory: true)
        .environment(SyncService.preview)
}
