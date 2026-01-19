import SwiftUI
import SwiftData

enum QueuePlaylistsTab: String, CaseIterable {
    case queue = "Queue"
    case playlists = "Playlists"
}

struct QueuePlaylistsView: View {
    @State private var selectedTab: QueuePlaylistsTab = .queue

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segmented control
                Picker("", selection: $selectedTab) {
                    ForEach(QueuePlaylistsTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)

                // Content based on selected tab
                switch selectedTab {
                case .queue:
                    QueueContentView()
                case .playlists:
                    PlaylistsContentView()
                }
            }
            .navigationTitle("Queue & Playlists")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Queue Content View

struct QueueContentView: View {
    @Environment(SyncService.self) private var syncService
    @Environment(AudioPlayerService.self) private var playerService
    @Query private var queueItems: [QueueItem]

    @State private var isLoading = false
    @State private var error: Error?

    private var sortedQueueItems: [QueueItem] {
        queueItems.sorted { $0.position < $1.position }
    }

    var body: some View {
        Group {
            if queueItems.isEmpty && !isLoading {
                emptyQueueView
            } else {
                queueList
            }
        }
        .task {
            await loadQueue()
        }
        .refreshable {
            await loadQueue()
        }
    }

    private var emptyQueueView: some View {
        ContentUnavailableView {
            Label("Queue Empty", systemImage: "list.bullet")
        } description: {
            Text("Swipe left on an episode and tap Queue to add it here")
        }
    }

    private var queueList: some View {
        List {
            ForEach(sortedQueueItems) { item in
                QueueItemRow(item: item)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            Task {
                                await removeFromQueue(item)
                            }
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            if let episode = item.episode {
                                Task {
                                    await playerService.play(episode)
                                }
                            }
                        } label: {
                            Label("Play", systemImage: "play.fill")
                        }
                        .tint(.green)
                    }
            }
            .onMove { indices, newOffset in
                Task {
                    await reorderQueue(from: indices, to: newOffset)
                }
            }

            if !queueItems.isEmpty {
                Section {
                    Button(role: .destructive) {
                        Task {
                            await clearQueue()
                        }
                    } label: {
                        Label("Clear Queue", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .listStyle(.plain)
        .environment(\.editMode, .constant(.active))
    }

    private func loadQueue() async {
        isLoading = true
        defer { isLoading = false }

        do {
            _ = try await syncService.getQueue()
        } catch {
            self.error = error
            print("Failed to load queue: \(error)")
        }
    }

    private func clearQueue() async {
        do {
            try await syncService.clearQueue()
        } catch {
            self.error = error
            print("Failed to clear queue: \(error)")
        }
    }

    private func removeFromQueue(_ item: QueueItem) async {
        do {
            try await syncService.removeFromQueue(queueItem: item)
        } catch {
            self.error = error
            print("Failed to remove from queue: \(error)")
        }
    }

    private func reorderQueue(from source: IndexSet, to destination: Int) async {
        var items = sortedQueueItems
        items.move(fromOffsets: source, toOffset: destination)

        do {
            try await syncService.reorderQueue(items: items)
        } catch {
            self.error = error
            print("Failed to reorder queue: \(error)")
        }
    }
}

// MARK: - Queue Item Row

struct QueueItemRow: View {
    let item: QueueItem

    var body: some View {
        HStack(spacing: 12) {
            // Drag handle
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.secondary)
                .font(.caption)

            // Artwork
            Group {
                if let episode = item.episode, let url = URL(string: episode.effectiveArtworkURL ?? "") {
                    AsyncImage(url: url) { image in
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
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.2))
                        .overlay {
                            Image(systemName: "waveform")
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(item.episode?.title ?? "Unknown Episode")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                if let podcastTitle = item.episode?.podcast?.title {
                    Text(podcastTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let duration = item.episode?.formattedDuration {
                    Text(duration)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            // Position indicator
            Text("#\(item.position + 1)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.secondary.opacity(0.1), in: Capsule())
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Playlists Content View

struct PlaylistsContentView: View {
    @Environment(SyncService.self) private var syncService
    @Query private var playlists: [Playlist]

    @State private var isLoading = false
    @State private var showingCreatePlaylist = false
    @State private var error: Error?

    var body: some View {
        Group {
            if playlists.isEmpty && !isLoading {
                emptyPlaylistsView
            } else {
                playlistsList
            }
        }
        .task {
            await loadPlaylists()
        }
        .refreshable {
            await loadPlaylists()
        }
        .sheet(isPresented: $showingCreatePlaylist) {
            CreatePlaylistView()
        }
    }

    private var emptyPlaylistsView: some View {
        ContentUnavailableView {
            Label("No Playlists", systemImage: "music.note.list")
        } description: {
            Text("Create playlists to organize your favorite episodes")
        } actions: {
            Button("Create Playlist") {
                showingCreatePlaylist = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var playlistsList: some View {
        List {
            ForEach(playlists) { playlist in
                NavigationLink {
                    PlaylistDetailView(playlist: playlist)
                } label: {
                    PlaylistRow(playlist: playlist)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        Task {
                            await deletePlaylist(playlist)
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }

            Section {
                Button {
                    showingCreatePlaylist = true
                } label: {
                    Label("Create New Playlist", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .listStyle(.plain)
    }

    private func loadPlaylists() async {
        isLoading = true
        defer { isLoading = false }

        do {
            _ = try await syncService.getPlaylists()
        } catch {
            self.error = error
            print("Failed to load playlists: \(error)")
        }
    }

    private func deletePlaylist(_ playlist: Playlist) async {
        do {
            try await syncService.deletePlaylist(playlist)
        } catch {
            self.error = error
            print("Failed to delete playlist: \(error)")
        }
    }
}

// MARK: - Playlist Row

struct PlaylistRow: View {
    let playlist: Playlist

    var body: some View {
        HStack(spacing: 12) {
            // Artwork placeholder with gradient
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.3), Color.accentColor.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 48, height: 48)
                .overlay {
                    Image(systemName: "music.note.list")
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(playlist.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                if let description = playlist.descriptionText, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text("\(playlist.itemCount) episode\(playlist.itemCount == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    QueuePlaylistsView()
        .environment(SyncService.preview)
        .environment(AudioPlayerService())
}
