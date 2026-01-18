import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(SyncService.self) private var syncService
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
                    } else {
                        recentlyPlayedSection
                        newEpisodesSection
                        statsSection
                    }
                }
                .padding(.horizontal)
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
                    NavigationLink(destination: ProgressView()) {
                        Text("See All")
                            .font(.subheadline)
                            .foregroundColor(.accentColor)
                    }
                }
            }

            if inProgressEpisodes.isEmpty {
                EmptyStateView(
                    icon: "headphones",
                    title: "No recent activity",
                    message: "Start listening to see your recently played episodes here"
                )
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
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("New Episodes")
                    .font(.headline)
                Spacer()
                if !newEpisodes.isEmpty {
                    NavigationLink(destination: LibraryView()) {
                        Text("See All")
                            .font(.subheadline)
                            .foregroundColor(.accentColor)
                    }
                }
            }

            if newEpisodes.isEmpty {
                EmptyStateView(
                    icon: "waveform",
                    title: "No new episodes",
                    message: "New episodes from your subscriptions will appear here"
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(newEpisodes.prefix(5)) { episode in
                        APIEpisodeRow(episode: episode)
                    }
                }
            }
        }
        .padding(.vertical, 8)
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

        } catch {
            errorMessage = error.localizedDescription
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

struct APIEpisodeRow: View {
    let episode: APIEpisode

    var body: some View {
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
            Image(systemName: "play.circle")
                .font(.title3)
                .foregroundColor(.accentColor)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
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
}