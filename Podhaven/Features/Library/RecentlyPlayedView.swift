import SwiftUI
import SwiftData

struct RecentlyPlayedView: View {
    @Environment(AudioPlayerService.self) private var playerService
    @Environment(SyncService.self) private var syncService

    @Query(
        filter: #Predicate<Episode> { $0.lastPlayedAt != nil },
        sort: \Episode.lastPlayedAt,
        order: .reverse
    )
    private var recentlyPlayedEpisodes: [Episode]

    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            Group {
                if recentlyPlayedEpisodes.isEmpty && !isLoading {
                    emptyState
                } else {
                    episodesList
                }
            }
            .navigationTitle("Recently Played")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !recentlyPlayedEpisodes.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            Task {
                                await syncProgress()
                            }
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                        .disabled(isLoading)
                    }
                }
            }
            .refreshable {
                await syncProgress()
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Recently Played", systemImage: "clock")
        } description: {
            Text("Episodes you've listened to will appear here")
        }
    }

    private var episodesList: some View {
        List {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }

            ForEach(recentlyPlayedEpisodes) { episode in
                EpisodeProgressRow(episode: episode)
                    .swipeActions(edge: .trailing) {
                        Button {
                            Task {
                                await resumeEpisode(episode)
                            }
                        } label: {
                            Label("Resume", systemImage: "play.fill")
                        }
                        .tint(.blue)
                    }
            }
        }
        .listStyle(.plain)
    }

    private func syncProgress() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await syncService.performSync()
        } catch {
            print("Failed to sync progress: \(error)")
        }
    }

    private func resumeEpisode(_ episode: episode) async {
        do {
            try await playerService.playEpisode(episode)
        } catch {
            print("Failed to resume episode: \(error)")
        }
    }
}

// MARK: - Episode Progress Row

struct EpisodeProgressRow: View {
    let episode: Episode

    @Environment(AudioPlayerService.self) private var playerService

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                // Artwork
                AsyncImage(url: episode.effectiveArtworkURL.flatMap { URL(string: $0) }) { image in
                    image
                        .resizable()
                        .aspectRatio(1, contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.2))
                        .overlay {
                            Image(systemName: "waveform")
                                .foregroundStyle(.secondary)
                        }
                }
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(episode.title)
                        .font(.headline)
                        .lineLimit(1)

                    if let podcastTitle = episode.podcast?.title {
                        Text(podcastTitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    // Progress info
                    HStack(spacing: 8) {
                        if episode.isPlayed {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                            Text("Completed")
                                .font(.caption)
                                .foregroundStyle(.green)
                        } else {
                            Text("\(episode.progress * 100, specifier: "%.0f")%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if let timeLeft = episode.remainingTime?.formattedTime() {
                            Text("· \(timeLeft) left")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                // Play button
                Button {
                    Task {
                        if let podcast = episode.podcast {
                            try? await playerService.playEpisode(episode)
                        }
                    }
                } label: {
                    Image(systemName: episode.isPlayed ? "checkmark.circle.fill" : "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(episode.isPlayed ? .green : .blue)
                }
                .buttonStyle(.plain)
            }

            // Progress bar
            if !episode.isPlayed {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 4)
                            .clipShape(Capsule())

                        Rectangle()
                            .fill(Color.blue)
                            .frame(width: geometry.size.width * episode.progress, height: 4)
                            .clipShape(Capsule())
                    }
                }
                .frame(height: 4)
            }
        }
        .padding(.vertical, 4)
    }
}

extension TimeInterval {
    func formattedTime() -> String {
        let hours = Int(self) / 3600
        let minutes = Int(self) / 60 % 60
        let seconds = Int(self) % 60

        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
}

#Preview {
    RecentlyPlayedView()
        .environment(AudioPlayerService())
        .environment(SyncService.preview)
}