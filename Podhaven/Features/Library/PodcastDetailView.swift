import SwiftUI
import SwiftData

struct PodcastDetailView: View {
    @Bindable var podcast: Podcast

    @Environment(\.modelContext) private var modelContext
    @Environment(AudioPlayerService.self) private var playerService
    @Environment(SyncService.self) private var syncService

    @State private var isRefreshing = false
    @State private var showingUnsubscribeAlert = false

    // MARK: - Pagination State

    /// Episodes to display (sorted by the current sort setting)
    @State private var displayedEpisodes: [Episode] = []
    /// Whether we're currently loading episodes
    @State private var isLoadingEpisodes = false
    /// Whether there are more episodes to load from the server
    @State private var hasMoreEpisodes = true
    /// Current offset for pagination
    @State private var currentOffset = 0
    /// Total episodes available on server
    @State private var totalEpisodes = 0
    /// Whether we're using local-only mode (no server connection)
    @State private var isLocalOnlyMode = false
    /// Error message to display
    @State private var loadError: String?

    /// Number of episodes to load per page
    private let pageSize = 50

    var body: some View {
        List {
            // Header
            Section {
                podcastHeader
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            // Episodes
            Section {
                episodeListHeader

                if displayedEpisodes.isEmpty && isLoadingEpisodes {
                    // Initial loading state
                    HStack {
                        Spacer()
                        ProgressView("Loading episodes...")
                        Spacer()
                    }
                    .padding(.vertical, 32)
                } else if displayedEpisodes.isEmpty && loadError != nil {
                    // Error state
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text(loadError ?? "Failed to load episodes")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button("Retry") {
                            Task {
                                await loadEpisodes(reset: true)
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                } else if displayedEpisodes.isEmpty {
                    // Empty state
                    Text("No episodes found")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                } else {
                    // Episode list with infinite scroll
                    ForEach(displayedEpisodes) { episode in
                        EpisodeRow(episode: episode)
                            .onAppear {
                                // Load more when approaching the end
                                if episode.id == displayedEpisodes.last?.id && hasMoreEpisodes && !isLoadingEpisodes {
                                    Task {
                                        await loadEpisodes()
                                    }
                                }
                            }
                    }

                    // Loading more indicator
                    if isLoadingEpisodes && !displayedEpisodes.isEmpty {
                        HStack {
                            Spacer()
                            ProgressView()
                                .padding(.vertical, 8)
                            Spacer()
                        }
                    }

                    // End of list indicator
                    if !hasMoreEpisodes && !displayedEpisodes.isEmpty {
                        Text("All \(displayedEpisodes.count) episodes loaded")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                }
            } header: {
                Text("Episodes")
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
                            await loadEpisodes(reset: true)
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
            await loadEpisodes(reset: true)
        }
        .task {
            await loadEpisodes(reset: true)
        }
    }

    // MARK: - Episode Loading

    private func loadEpisodes(reset: Bool = false) async {
        guard !isLoadingEpisodes else { return }

        // Don't load more if we've reached the end (unless resetting)
        if !reset && !hasMoreEpisodes { return }

        isLoadingEpisodes = true
        loadError = nil

        if reset {
            currentOffset = 0
            hasMoreEpisodes = true
        }

        // Check if podcast has server ID for API fetching
        guard podcast.serverPodcastId != nil else {
            // Fall back to local episodes
            fallbackToLocalEpisodes()
            isLoadingEpisodes = false
            return
        }

        do {
            let response = try await syncService.getEpisodes(
                for: podcast,
                limit: pageSize,
                offset: currentOffset
            )

            // Sync fetched episodes to local SwiftData for offline access
            syncService.syncAPIEpisodesToLocal(response.episodes, for: podcast)

            // Update displayed episodes from local data (now synced)
            updateDisplayedEpisodesFromLocal(appendCount: response.episodes.count, reset: reset)

            totalEpisodes = response.total
            currentOffset += response.episodes.count
            hasMoreEpisodes = currentOffset < totalEpisodes
            isLocalOnlyMode = false

        } catch {
            print("PodcastDetailView: Failed to load episodes from server: \(error)")

            if reset {
                // On initial load failure, fall back to local episodes
                fallbackToLocalEpisodes()
                if displayedEpisodes.isEmpty {
                    loadError = "Unable to load episodes. Check your connection."
                }
            }
            // For pagination errors, just stop loading more (keep existing episodes)
            hasMoreEpisodes = false
        }

        isLoadingEpisodes = false
    }

    /// Update displayed episodes from local SwiftData
    private func updateDisplayedEpisodesFromLocal(appendCount: Int, reset: Bool) {
        let sorted = sortedLocalEpisodes

        if reset {
            // Take first batch
            displayedEpisodes = Array(sorted.prefix(currentOffset + appendCount))
        } else {
            // Append new episodes
            let newEpisodes = Array(sorted.prefix(currentOffset + appendCount))
            displayedEpisodes = newEpisodes
        }
    }

    /// Fall back to local SwiftData episodes when offline or not synced
    private func fallbackToLocalEpisodes() {
        isLocalOnlyMode = true
        displayedEpisodes = sortedLocalEpisodes
        totalEpisodes = displayedEpisodes.count
        hasMoreEpisodes = false
    }

    /// Episodes sorted according to podcast settings
    private var sortedLocalEpisodes: [Episode] {
        let sort = podcast.customEpisodeSort ?? "newest"
        let filter = podcast.customEpisodeFilter ?? "all"

        var episodes = podcast.episodes

        // Apply filter
        switch filter {
        case "unplayed":
            episodes = episodes.filter { !$0.isPlayed }
        case "downloaded":
            episodes = episodes.filter { $0.downloadState == .downloaded }
        case "in_progress":
            episodes = episodes.filter { $0.playbackPosition > 0 && !$0.isPlayed }
        default:
            break // "all" - no filter
        }

        // Apply sort
        switch sort {
        case "oldest":
            return episodes.sorted { ($0.publishDate ?? .distantPast) < ($1.publishDate ?? .distantPast) }
        case "shortest":
            return episodes.sorted { ($0.duration ?? 0) < ($1.duration ?? 0) }
        case "longest":
            return episodes.sorted { ($0.duration ?? 0) > ($1.duration ?? 0) }
        default: // "newest"
            return episodes.sorted { ($0.publishDate ?? .distantPast) > ($1.publishDate ?? .distantPast) }
        }
    }

    // MARK: - Views

    private var episodeListHeader: some View {
        HStack {
            if isLocalOnlyMode {
                Label("Offline Mode", systemImage: "wifi.slash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if totalEpisodes > 0 {
                Text("\(totalEpisodes) episodes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
        .listRowBackground(Color.clear)
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

                    if totalEpisodes > 0 {
                        Text("\(totalEpisodes) episodes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(podcast.episodes.count) episodes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

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
