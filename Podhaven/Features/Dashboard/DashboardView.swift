import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(SyncService.self) private var syncService
    @Environment(AudioPlayerService.self) private var playerService
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<Episode> { !$0.isPlayed && $0.playbackPosition > 0 }, sort: \Episode.lastPlayedAt, order: .reverse)
    private var inProgressEpisodes: [Episode]

    @State private var dashboardStats: DashboardStats?
    @State private var newEpisodes: [APIEpisode] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if isLoading {
                        ProgressView()
                            .padding(.top, 50)
                    } else if let error = errorMessage {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.largeTitle)
                                .foregroundColor(.orange)
                            Text("Failed to load dashboard")
                                .font(.headline)
                            Text(error)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            Button("Retry") {
                                Task {
                                    await loadDashboard()
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.top, 50)
                        .padding(.horizontal)
                    } else {
                        recentlyPlayedSection
                        newEpisodesSection
                        statsSection
                            .padding(.horizontal)
                    }
                }
                .padding(.bottom, 100) // Space for mini player
            }
            .navigationTitle("Dashboard")
            .refreshable {
                await loadDashboard()
            }
        }
        .task {
            await loadDashboard()
        }
    }

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Listening Stats")
                .font(.headline)
                .foregroundColor(.primary)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 16) {
                StatCard(
                    title: "Total Time",
                    value: formatListeningTime(dashboardStats?.totalListeningTimeSeconds ?? 0),
                    icon: "clock"
                )

                StatCard(
                    title: "Completed",
                    value: "\(dashboardStats?.totalEpisodesCompleted ?? 0)",
                    icon: "checkmark.circle.fill"
                )

                StatCard(
                    title: "In Progress",
                    value: "\(dashboardStats?.totalEpisodesInProgress ?? 0)",
                    icon: "play.circle.fill"
                )

                StatCard(
                    title: "Subscriptions",
                    value: "\(dashboardStats?.totalPodcastsSubscribed ?? 0)",
                    icon: "antenna.radiowaves.left.and.right"
                )
            }
        }
        .padding(.vertical, 8)
    }

    private var recentlyPlayedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Continue Listening")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                if !inProgressEpisodes.isEmpty {
                    NavigationLink(destination: ListeningProgressView()) {
                        Text("See All")
                            .font(.subheadline)
                            .foregroundColor(.accentColor)
                    }
                }
            }
            .padding(.horizontal)

            if inProgressEpisodes.isEmpty {
                EmptyStateView(
                    icon: "headphones",
                    title: "No recent activity",
                    message: "Start listening to see your recently played episodes here"
                )
                .padding(.horizontal)
            } else {
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
        .padding(.vertical, 8)
    }

    private var newEpisodesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("New Episodes")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                if !unplayedNewEpisodes.isEmpty {
                    NavigationLink(destination: LibraryView()) {
                        Text("See All")
                            .font(.subheadline)
                            .foregroundColor(.accentColor)
                    }
                }
            }
            .padding(.horizontal)

            if unplayedNewEpisodes.isEmpty {
                EmptyStateView(
                    icon: "waveform",
                    title: "No new episodes",
                    message: "New episodes from your subscriptions will appear here"
                )
                .padding(.horizontal)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(unplayedNewEpisodes.prefix(10)) { episode in
                            NewEpisodeCard(episode: episode) {
                                playAPIEpisode(episode)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding(.vertical, 8)
    }

    /// Filter new episodes to exclude those that are already played
    private var unplayedNewEpisodes: [APIEpisode] {
        newEpisodes.filter { apiEpisode in
            !isEpisodePlayed(apiEpisode)
        }
    }

    /// Check if an API episode corresponds to a played local episode
    private func isEpisodePlayed(_ apiEpisode: APIEpisode) -> Bool {
        let episodeId = apiEpisode.id
        let audioUrl = apiEpisode.audioUrl

        let descriptor = FetchDescriptor<Episode>(
            predicate: #Predicate<Episode> { episode in
                (episode.serverEpisodeId == episodeId || episode.audioURL == audioUrl) && episode.isPlayed
            }
        )

        do {
            let playedEpisodes = try modelContext.fetch(descriptor)
            return !playedEpisodes.isEmpty
        } catch {
            return false
        }
    }

    private func loadDashboard() async {
        isLoading = true
        errorMessage = nil

        do {
            // Load stats
            let statsResponse = try await syncService.getDashboardStats()
            dashboardStats = statsResponse.stats

            // Load new episodes (from last 7 days)
            let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())
            let newEpisodesResponse = try await syncService.getNewEpisodes(
                fromDate: sevenDaysAgo,
                limit: 10
            )
            newEpisodes = newEpisodesResponse.episodes

            // Recently played now uses local in-progress episodes via @Query
            // No API call needed

        } catch is CancellationError {
            // Task was cancelled (e.g., during pull-to-refresh), ignore silently
        } catch let urlError as URLError where urlError.code == .cancelled {
            // URLSession task was cancelled, ignore silently
        } catch {
            // Only show error if we don't already have data
            if dashboardStats == nil && newEpisodes.isEmpty {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }

    private func formatListeningTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    private func playAPIEpisode(_ apiEpisode: APIEpisode) {
        // Find the local Episode using an efficient fetch with predicate
        let episodeId = apiEpisode.id
        let audioUrl = apiEpisode.audioUrl

        // Create a predicate to find the matching episode
        let descriptor = FetchDescriptor<Episode>(
            predicate: #Predicate<Episode> { episode in
                episode.serverEpisodeId == episodeId || episode.audioURL == audioUrl
            }
        )

        do {
            let matchingEpisodes = try modelContext.fetch(descriptor)
            if let episode = matchingEpisodes.first {
                Task {
                    await playerService.play(episode)
                }
            }
        } catch {
            print("Failed to find local episode: \(error)")
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                Spacer()
            }

            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial)
        .cornerRadius(12)
    }
}

// MARK: - New Episode Card

struct NewEpisodeCard: View {
    let episode: APIEpisode
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button {
            onTap?()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                // Artwork
                ZStack(alignment: .bottomTrailing) {
                    if let artworkUrl = episode.podcast?.artworkUrl ?? episode.artworkUrl,
                       let url = URL(string: artworkUrl) {
                        AsyncImage(url: url) { image in
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
                        .frame(width: 140, height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.secondary.opacity(0.2))
                            .frame(width: 140, height: 140)
                            .overlay {
                                Image(systemName: "waveform")
                                    .foregroundStyle(.secondary)
                            }
                    }

                    // Play button overlay
                    Image(systemName: "play.circle.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                        .padding(8)
                }

                // Episode info
                VStack(alignment: .leading, spacing: 4) {
                    Text(episode.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(2)
                        .foregroundStyle(.primary)

                    if let podcastTitle = episode.podcast?.title {
                        Text(podcastTitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    HStack(spacing: 4) {
                        if let duration = episode.durationSeconds {
                            Text(formatDuration(duration))
                        }
                        if episode.durationSeconds != nil && episode.publishedAt != nil {
                            Text("•")
                        }
                        if let publishDate = episode.publishedAt {
                            Text(formatRelativeDate(publishDate))
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                }
                .frame(width: 140, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    private func formatRelativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct APIEpisodeRow: View {
    let episode: APIEpisode
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(spacing: 12) {
                // Podcast artwork
                if let artworkUrl = episode.podcast?.artworkUrl ?? episode.artworkUrl,
                   let url = URL(string: artworkUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.gray.opacity(0.3)
                    }
                    .frame(width: 50, height: 50)
                    .cornerRadius(8)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "headphones")
                                .foregroundColor(.secondary)
                        )
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(episode.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(2)
                        .foregroundStyle(.primary)

                    if let podcastTitle = episode.podcast?.title {
                        Text(podcastTitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    HStack(spacing: 8) {
                        if let duration = episode.durationSeconds {
                            Text(formatDuration(duration))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        if let publishDate = episode.publishedAt {
                            Text(formatDate(publishDate))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                // Play button
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    DashboardView()
        .environment(SyncService.preview)
        .environment(AudioPlayerService())
}