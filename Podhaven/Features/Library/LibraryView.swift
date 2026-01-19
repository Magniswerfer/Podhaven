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

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SyncService.self) private var syncService
    @Environment(AudioPlayerService.self) private var playerService

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
                // Podcasts section
                VStack(alignment: .leading, spacing: 12) {

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
            .padding(.bottom, playerService.currentEpisode != nil ? 120 : 0) // Add padding for miniplayer
        }
    }
    
    private func refreshAllPodcasts() async {
        isRefreshing = true
        defer { isRefreshing = false }

        // Refresh podcasts concurrently with a limit of 3 concurrent requests
        // to avoid overwhelming the network while still being faster than sequential
        let maxConcurrency = 3

        await withTaskGroup(of: Void.self) { group in
            var runningTasks = 0
            var podcastIndex = 0

            for podcast in podcasts {
                // Wait if we've reached max concurrency
                if runningTasks >= maxConcurrency {
                    await group.next()
                    runningTasks -= 1
                }

                group.addTask {
                    try? await self.syncService.refreshPodcast(podcast)
                }
                runningTasks += 1
                podcastIndex += 1
            }

            // Wait for remaining tasks
            await group.waitForAll()
        }
    }
}

// MARK: - Podcast Grid Item

struct PodcastGridItem: View {
    let podcast: Podcast
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Artwork
            AsyncImage(url: URL(string: podcast.effectiveArtworkURL ?? "")) { phase in
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
            
            // Text container with fixed height for grid alignment
            VStack(alignment: .leading, spacing: 4) {
                Text(podcast.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if podcast.unplayedCount > 0 {
                    Text("\(podcast.unplayedCount) unplayed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0) // Push content to top, maintain grid alignment
            }
            .frame(height: 70, alignment: .topLeading) // Fixed height for grid alignment
            .frame(maxWidth: .infinity, alignment: .leading)
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
