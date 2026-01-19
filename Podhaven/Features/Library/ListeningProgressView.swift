import SwiftUI
import SwiftData

struct ListeningProgressView: View {
    @Environment(AudioPlayerService.self) private var playerService
    @Environment(SyncService.self) private var syncService

    @Query(filter: #Predicate<Episode> { $0.lastPlayedAt != nil })
    private var episodesWithProgress: [Episode]

    @State private var selectedSegment = 0
    @State private var isLoading = false

    private let segments = ["In Progress", "Completed", "Recently Played"]

    private var inProgressEpisodes: [Episode] {
        episodesWithProgress
            .filter { !$0.isPlayed && $0.playbackPosition > 0 }
            .sorted { ($0.lastPlayedAt ?? .distantPast) > ($1.lastPlayedAt ?? .distantPast) }
    }

    private var completedEpisodes: [Episode] {
        episodesWithProgress
            .filter { $0.isPlayed }
            .sorted { ($0.lastPlayedAt ?? .distantPast) > ($1.lastPlayedAt ?? .distantPast) }
    }

    private var recentlyPlayedEpisodes: [Episode] {
        episodesWithProgress
            .sorted { ($0.lastPlayedAt ?? .distantPast) > ($1.lastPlayedAt ?? .distantPast) }
    }

    private var currentEpisodes: [Episode] {
        switch selectedSegment {
        case 0: return inProgressEpisodes
        case 1: return completedEpisodes
        case 2: return recentlyPlayedEpisodes
        default: return []
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segment picker
                Picker("Progress Type", selection: $selectedSegment) {
                    ForEach(0..<segments.count, id: \.self) { index in
                        Text(segments[index])
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                Group {
                    if currentEpisodes.isEmpty && !isLoading {
                        emptyState
                    } else {
                        episodesList
                    }
                }
            }
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
            .refreshable {
                await syncProgress()
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(emptyStateIcon, systemImage: emptyStateIcon == "clock" ? "clock" : "checkmark.circle")
        } description: {
            Text(emptyStateMessage)
        }
    }

    private var emptyStateIcon: String {
        switch selectedSegment {
        case 0: return "play.circle"
        case 1: return "checkmark.circle"
        case 2: return "clock"
        default: return "circle"
        }
    }

    private var emptyStateMessage: String {
        switch selectedSegment {
        case 0: return "No episodes in progress. Start listening to see your progress here."
        case 1: return "No completed episodes yet. Finish listening to episodes to see them here."
        case 2: return "No recently played episodes. Episodes you listen to will appear here."
        default: return ""
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

            ForEach(currentEpisodes) { episode in
                EpisodeProgressRow(episode: episode)
                    .swipeActions(edge: HorizontalEdge.trailing) {
                        if selectedSegment == 0 {
                            // In progress - can resume or mark complete
                            Button {
                                Task {
                                    await resumeEpisode(episode)
                                }
                            } label: {
                                Label("Resume", systemImage: "play.fill")
                            }
                            .tint(.blue)

                            Button {
                                Task {
                                    await markCompleted(episode)
                                }
                            } label: {
                                Label("Mark Complete", systemImage: "checkmark.circle")
                            }
                            .tint(.green)
                        } else if selectedSegment == 1 {
                            // Completed - can replay
                            Button {
                                Task {
                                    await resumeEpisode(episode)
                                }
                            } label: {
                                Label("Replay", systemImage: "arrow.clockwise")
                            }
                            .tint(.orange)
                        } else {
                            // Recently played - can resume
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

    private func resumeEpisode(_ episode: Episode) async {
        await playerService.play(episode)
    }

    private func markCompleted(_ episode: Episode) async {
        do {
            try await syncService.recordProgress(
                episode: episode,
                position: episode.duration ?? 0,
                completed: true
            )
        } catch {
            print("Failed to mark episode as completed: \(error)")
        }
    }
}

struct EpisodeProgressRow: View {
    let episode: Episode

    @Environment(AudioPlayerService.self) private var playerService

    private var isCurrentEpisode: Bool {
        playerService.currentEpisode?.id == episode.id
    }

    var body: some View {
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

                if let podcastTitle = episode.podcast?.title {
                    Text(podcastTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    if episode.isPlayed {
                        Text("✓ Completed")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    } else if episode.playbackPosition > 0 {
                        Text("\(Int(episode.progress * 100))% · \(episode.remainingTime?.formattedTime() ?? "") left")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if let lastPlayed = episode.lastPlayedAt {
                        Text(lastPlayed, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // Play button
            Image(systemName: episode.isPlayed ? "checkmark.circle.fill" : "play.circle")
                .font(.title3)
                .foregroundStyle(episode.isPlayed ? .green : .accentColor)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

#Preview {
    ListeningProgressView()
        .environment(AudioPlayerService())
        .environment(SyncService.preview)
}