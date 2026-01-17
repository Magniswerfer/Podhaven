import SwiftUI
import SwiftData

// MARK: - Continue Listening Card

struct ContinueListeningCard: View {
    let episode: Episode

    @Environment(AudioPlayerService.self) private var playerService

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Artwork
            ZStack(alignment: .bottomTrailing) {
                AsyncImage(url: episode.effectiveArtworkURL.flatMap { URL(string: $0) }) { image in
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
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Progress overlay
                if !episode.isPlayed {
                    CircularProgressView(progress: episode.progress)
                        .frame(width: 32, height: 32)
                        .padding(8)
                }
            }

            // Episode info
            VStack(alignment: .leading, spacing: 4) {
                Text(episode.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)

                if let podcastTitle = episode.podcast?.title {
                    Text(podcastTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if !episode.isPlayed {
                    Text("\(Int(episode.progress * 100))% · \(episode.remainingTime?.formattedTime() ?? "") left")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 120, alignment: .leading)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            Task {
                await playerService.play(episode)
            }
        }
    }
}

// MARK: - Circular Progress View

struct CircularProgressView: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.black.opacity(0.2), lineWidth: 3)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

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
                    HStack {
                        NavigationLink {
                            RecentlyPlayedView()
                        } label: {
                            Image(systemName: "clock")
                        }

                        NavigationLink {
                            ProgressView()
                        } label: {
                            Image(systemName: "chart.bar")
                        }

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
            VStack(alignment: .leading, spacing: 24) {
                // Continue Listening section
                if !inProgressEpisodes.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Continue Listening")
                            .font(.title2)
                            .fontWeight(.bold)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(inProgressEpisodes.prefix(5)) { episode in
                                    ContinueListeningCard(episode: episode)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }

                // Podcasts section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Podcasts")
                        .font(.title2)
                        .fontWeight(.bold)

                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 150, maximum: 180), spacing: 16)
                    ], spacing: 16) {
                        ForEach(podcasts) { podcast in
                            NavigationLink {
                                PodcastDetailView(podcast: podcast)
                            } label: {
                                PodcastGridItem(podcast: podcast)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }

    private var inProgressEpisodes: [Episode] {
        podcasts
            .flatMap { $0.episodes }
            .filter { !$0.isPlayed && $0.playbackPosition > 0 }
            .sorted { ($0.lastPlayedAt ?? .distantPast) > ($1.lastPlayedAt ?? .distantPast) }
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
