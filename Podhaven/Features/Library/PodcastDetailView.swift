import SwiftUI
import SwiftData

struct PodcastDetailView: View {
    @Bindable var podcast: Podcast
    
    @Environment(\.modelContext) private var modelContext
    @Environment(AudioPlayerService.self) private var playerService
    @Environment(SyncService.self) private var syncService
    
    @State private var isRefreshing = false
    @State private var showingUnsubscribeAlert = false
    
    private var sortedEpisodes: [Episode] {
        podcast.episodes.sorted { ($0.publishDate ?? .distantPast) > ($1.publishDate ?? .distantPast) }
    }
    
    var body: some View {
        List {
            // Header
            Section {
                podcastHeader
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            
            // Episodes
            Section("Episodes") {
                ForEach(sortedEpisodes) { episode in
                    EpisodeRow(episode: episode)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(podcast.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        Task {
                            isRefreshing = true
                            try? await syncService.refreshPodcast(podcast)
                            isRefreshing = false
                        }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    
                    Button(role: .destructive) {
                        showingUnsubscribeAlert = true
                    } label: {
                        Label("Unsubscribe", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("Unsubscribe", isPresented: $showingUnsubscribeAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Unsubscribe", role: .destructive) {
                Task {
                    try? await syncService.unsubscribe(from: podcast)
                }
            }
        } message: {
            Text("Are you sure you want to unsubscribe from \(podcast.title)?")
        }
        .refreshable {
            try? await syncService.refreshPodcast(podcast)
        }
    }
    
    private var podcastHeader: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                // Artwork
                AsyncImage(url: URL(string: podcast.artworkURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(1, contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.secondary.opacity(0.2))
                        .overlay {
                            Image(systemName: "waveform")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                        }
                }
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(radius: 4)
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(podcast.title)
                        .font(.headline)
                    
                    if let author = podcast.author {
                        Text(author)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Text("\(podcast.episodes.count) episodes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                }
                
                Spacer()
            }
            
            // Description
            if let description = podcast.podcastDescription {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding()
    }
}

// MARK: - Episode Row

struct EpisodeRow: View {
    @Bindable var episode: Episode
    
    @Environment(AudioPlayerService.self) private var playerService
    @Environment(SyncService.self) private var syncService
    
    @State private var showingShowNotes = false
    
    private var isCurrentEpisode: Bool {
        playerService.currentEpisode?.id == episode.id
    }
    
    var body: some View {
        Button {
            Task {
                await playerService.play(episode)
            }
        } label: {
            HStack(spacing: 12) {
                // Play indicator or artwork
                ZStack {
                    if let artworkURL = episode.effectiveArtworkURL,
                       let url = URL(string: artworkURL) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(1, contentMode: .fill)
                        } placeholder: {
                            Color.secondary.opacity(0.2)
                        }
                    } else {
                        Color.secondary.opacity(0.2)
                    }
                    
                    if isCurrentEpisode && playerService.isPlaying {
                        Color.black.opacity(0.4)
                        Image(systemName: "waveform")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .symbolEffect(.variableColor.iterative)
                    }
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                // Episode info
                VStack(alignment: .leading, spacing: 4) {
                    Text(episode.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(2)
                        .foregroundStyle(episode.isPlayed ? .secondary : .primary)
                    
                    HStack(spacing: 8) {
                        if let date = episode.publishDate {
                            Text(date, style: .date)
                        }
                        
                        if let duration = episode.formattedDuration {
                            Text("•")
                            Text(duration)
                        }
                        
                        if episode.downloadState == .downloaded {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    
                    // Progress bar
                    if episode.progress > 0 && episode.progress < 1 {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.secondary.opacity(0.2))
                                
                                Capsule()
                                    .fill(Color.accentColor)
                                    .frame(width: geo.size.width * episode.progress)
                            }
                        }
                        .frame(height: 3)
                    }
                }
                
                Spacer()
                
                // Info button for show notes
                Button {
                    showingShowNotes = true
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                
                // Download button
                Button {
                    // Download action
                } label: {
                    Image(systemName: downloadIcon)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                showingShowNotes = true
            } label: {
                Label("Show Notes", systemImage: "doc.text")
            }
            
            Button {
                Task {
                    try? await syncService.markEpisodePlayed(episode, played: !episode.isPlayed)
                }
            } label: {
                Label(
                    episode.isPlayed ? "Mark as Unplayed" : "Mark as Played",
                    systemImage: episode.isPlayed ? "circle" : "checkmark.circle"
                )
            }
        }
        .sheet(isPresented: $showingShowNotes) {
            ShowNotesView(episode: episode)
        }
    }
    
    private var downloadIcon: String {
        switch episode.downloadState {
        case .notDownloaded:
            return "arrow.down.circle"
        case .downloading:
            return "stop.circle"
        case .downloaded:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.circle"
        }
    }
}

#Preview {
    NavigationStack {
        PodcastDetailView(podcast: .sample)
    }
    .environment(AudioPlayerService())
    .environment(SyncService.preview)
}
