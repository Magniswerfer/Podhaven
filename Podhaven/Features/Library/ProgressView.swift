import SwiftUI
import SwiftData

struct ProgressView: View {
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
                    .swipeActions(edge: .trailing) {
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
        do {
            try await playerService.playEpisode(episode)
        } catch {
            print("Failed to resume episode: \(error)")
        }
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

#Preview {
    ProgressView()
        .environment(AudioPlayerService())
        .environment(SyncService.preview)
}