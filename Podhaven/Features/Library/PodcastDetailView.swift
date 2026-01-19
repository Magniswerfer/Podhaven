import SwiftUI
import SwiftData

// MARK: - Filter & Sort Options

enum EpisodeFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case unplayed = "Unplayed"
    case inProgress = "In Progress"
    case uncompleted = "Uncompleted"

    var id: Self { self }

    var apiValue: String {
        switch self {
        case .all: return "all"
        case .unplayed: return "unplayed"
        case .inProgress: return "in-progress"
        case .uncompleted: return "uncompleted"
        }
    }

    var icon: String {
        switch self {
        case .all: return "list.bullet"
        case .unplayed: return "circle"
        case .inProgress: return "play.circle"
        case .uncompleted: return "circle.lefthalf.filled"
        }
    }

    init?(apiValue: String?) {
        guard let apiValue else { self = .all; return }
        self = Self.allCases.first { $0.apiValue == apiValue } ?? .all
    }
}

enum EpisodeSort: String, CaseIterable, Identifiable {
    case newest = "Newest"
    case oldest = "Oldest"

    var id: Self { self }

    var apiValue: String {
        switch self {
        case .newest: return "newest"
        case .oldest: return "oldest"
        }
    }

    var icon: String {
        switch self {
        case .newest: return "arrow.down"
        case .oldest: return "arrow.up"
        }
    }

    init?(apiValue: String?) {
        guard let apiValue else { self = .newest; return }
        self = Self.allCases.first { $0.apiValue == apiValue } ?? .newest
    }
}

struct PodcastDetailView: View {
    @Bindable var podcast: Podcast

    @Environment(\.modelContext) private var modelContext
    @Environment(AudioPlayerService.self) private var playerService
    @Environment(SyncService.self) private var syncService

    @State private var isRefreshing = false
    @State private var showingUnsubscribeAlert = false

    // MARK: - Filter & Sort State

    @State private var selectedFilter: EpisodeFilter = .all
    @State private var selectedSort: EpisodeSort = .newest

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

    init(podcast: Podcast) {
        self.podcast = podcast
        // Initialize filter/sort from podcast's saved settings
        _selectedFilter = State(initialValue: EpisodeFilter(apiValue: podcast.customEpisodeFilter) ?? .all)
        _selectedSort = State(initialValue: EpisodeSort(apiValue: podcast.customEpisodeSort) ?? .newest)
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
            Section {
                episodeListHeader

                if displayedEpisodes.isEmpty && isLoadingEpisodes {
                    // Initial loading state
                    HStack {
                        Spacer()
                        SwiftUI.ProgressView("Loading episodes...")
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
                            SwiftUI.ProgressView()
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
        .onChange(of: selectedFilter) { _, newFilter in
            Task {
                // Reset and reload with new filter
                await loadEpisodes(reset: true)
                // Save preference to podcast settings
                try? await syncService.updatePodcastSettings(
                    for: podcast,
                    filter: newFilter.apiValue,
                    sort: nil
                )
            }
        }
        .onChange(of: selectedSort) { _, newSort in
            Task {
                // Reset and reload with new sort
                await loadEpisodes(reset: true)
                // Save preference to podcast settings
                try? await syncService.updatePodcastSettings(
                    for: podcast,
                    filter: nil,
                    sort: newSort.apiValue
                )
            }
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
                offset: currentOffset,
                filter: selectedFilter.apiValue,
                sort: selectedSort.apiValue
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

    /// Episodes sorted according to current filter/sort selection
    private var sortedLocalEpisodes: [Episode] {
        var episodes = podcast.episodes

        // Apply filter based on selected filter
        switch selectedFilter {
        case .all:
            break // No filter
        case .unplayed:
            episodes = episodes.filter { !$0.isPlayed }
        case .inProgress:
            episodes = episodes.filter { $0.playbackPosition > 0 && !$0.isPlayed }
        case .uncompleted:
            episodes = episodes.filter { !$0.isPlayed }
        }

        // Apply sort based on selected sort
        switch selectedSort {
        case .newest:
            return episodes.sorted { ($0.publishDate ?? .distantPast) > ($1.publishDate ?? .distantPast) }
        case .oldest:
            return episodes.sorted { ($0.publishDate ?? .distantPast) < ($1.publishDate ?? .distantPast) }
        }
    }

    // MARK: - Views

    private var filterMenuWidth: CGFloat {
        // Fixed width that accommodates the longest filter text ("In Progress")
        // Icon (16) + spacing (4) + text width (estimate 70) + horizontal padding (16) + buffer (10)
        return 116
    }

    private var episodeListHeader: some View {
        HStack(spacing: 12) {
            // Episode count and status
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

            // Filter Menu
            Menu {
                ForEach(EpisodeFilter.allCases) { filter in
                    Button {
                        selectedFilter = filter
                    } label: {
                        Label(filter.rawValue, systemImage: filter.icon)
                        if selectedFilter == filter {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: selectedFilter.icon)
                    Text(selectedFilter.rawValue)
                }
                .font(.caption)
                .foregroundStyle(selectedFilter == .all ? .secondary : Color.accentColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .frame(width: filterMenuWidth, alignment: .center)
                .background(
                    Capsule()
                        .fill(selectedFilter == .all ? Color.secondary.opacity(0.1) : Color.accentColor.opacity(0.1))
                )
            }

            // Sort Menu
            Menu {
                ForEach(EpisodeSort.allCases) { sort in
                    Button {
                        selectedSort = sort
                    } label: {
                        Label(sort.rawValue, systemImage: sort.icon)
                        if selectedSort == sort {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: selectedSort.icon)
                    Text(selectedSort.rawValue)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.secondary.opacity(0.1))
                )
            }
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
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
    @Environment(DownloadService.self) private var downloadService: DownloadService?

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

                // Chevron to indicate tappability
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
        // Leading swipe: Mark Played/Unplayed
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                Task {
                    try? await syncService.markEpisodePlayed(episode, played: !episode.isPlayed)
                }
            } label: {
                Label(
                    episode.isPlayed ? "Unplayed" : "Played",
                    systemImage: episode.isPlayed ? "circle" : "checkmark.circle.fill"
                )
            }
            .tint(episode.isPlayed ? .orange : .green)
        }
        // Trailing swipe: Add to Queue, Download
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                Task {
                    try? await syncService.addToQueue(episode: episode)
                }
            } label: {
                Label("Queue", systemImage: "text.badge.plus")
            }
            .tint(.indigo)

            if episode.downloadState == .notDownloaded {
                Button {
                    Task {
                        try? await downloadService?.download(episode)
                    }
                } label: {
                    Label("Download", systemImage: "arrow.down.circle")
                }
                .tint(.blue)
            } else if episode.downloadState == .downloaded {
                Button(role: .destructive) {
                    try? downloadService?.deleteDownload(for: episode)
                } label: {
                    Label("Remove", systemImage: "trash")
                }
            }
        }
        .contextMenu {
            Button {
                showingShowNotes = true
            } label: {
                Label("Show Notes", systemImage: "doc.text")
            }

            Button {
                Task {
                    try? await syncService.addToQueue(episode: episode)
                }
            } label: {
                Label("Add to Queue", systemImage: "text.badge.plus")
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

            Divider()

            if episode.downloadState == .notDownloaded {
                Button {
                    Task {
                        try? await downloadService?.download(episode)
                    }
                } label: {
                    Label("Download", systemImage: "arrow.down.circle")
                }
            } else if episode.downloadState == .downloaded {
                Button(role: .destructive) {
                    try? downloadService?.deleteDownload(for: episode)
                } label: {
                    Label("Delete Download", systemImage: "trash")
                }
            }
        }
        .sheet(isPresented: $showingShowNotes) {
            ShowNotesView(episode: episode)
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
