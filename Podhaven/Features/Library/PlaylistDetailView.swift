import SwiftUI
import SwiftData

struct PlaylistDetailView: View {
    @Environment(SyncService.self) private var syncService

    let playlist: Playlist

    @State private var showingEditPlaylist = false
    @State private var showingAddItems = false
    @State private var isLoading = false
    @State private var error: Error?

    private var sortedItems: [PlaylistItem] {
        playlist.sortedItems
    }

    var body: some View {
        List {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowBackground(Color.clear)
            } else if sortedItems.isEmpty {
                emptyPlaylistView
            } else {
                itemsList
            }
        }
        .navigationTitle(playlist.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showingEditPlaylist = true
                    } label: {
                        Label("Edit Playlist", systemImage: "pencil")
                    }

                    Button {
                        showingAddItems = true
                    } label: {
                        Label("Add Episodes", systemImage: "plus")
                    }

                    Divider()

                    Button(role: .destructive) {
                        Task {
                            await deletePlaylist()
                        }
                    } label: {
                        Label("Delete Playlist", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
        .task {
            await loadPlaylist()
        }
        .sheet(isPresented: $showingEditPlaylist) {
            EditPlaylistView(playlist: playlist)
        }
        .sheet(isPresented: $showingAddItems) {
            AddToPlaylistView(playlist: playlist)
        }
    }

    private var emptyPlaylistView: some View {
        Section {
            ContentUnavailableView {
                Label("Empty Playlist", systemImage: "music.note.list")
            } description: {
                Text("Add episodes to get started")
            } actions: {
                Button("Add Episodes") {
                    showingAddItems = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var itemsList: some View {
        ForEach(sortedItems) { item in
            PlaylistItemRow(item: item)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        Task {
                            await removeItem(item)
                        }
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                }
        }
        .onMove { indices, newOffset in
            Task {
                await reorderItems(from: indices, to: newOffset)
            }
        }
        .environment(\.editMode, .constant(.active))
    }

    private func loadPlaylist() async {
        isLoading = true
        defer { isLoading = false }

        do {
            _ = try await syncService.getPlaylist(id: playlist.id)
        } catch {
            self.error = error
            print("Failed to load playlist: \(error)")
        }
    }

    private func removeItem(_ item: PlaylistItem) async {
        do {
            try await syncService.removeFromPlaylist(playlist, item: item)
        } catch {
            self.error = error
            print("Failed to remove item: \(error)")
        }
    }

    private func reorderItems(from source: IndexSet, to destination: Int) async {
        var items = sortedItems
        items.move(fromOffsets: source, toOffset: destination)

        do {
            try await syncService.reorderPlaylistItems(playlist, items: items)
        } catch {
            self.error = error
            print("Failed to reorder items: \(error)")
        }
    }

    private func deletePlaylist() async {
        do {
            try await syncService.deletePlaylist(playlist)
            // Navigation will handle going back
        } catch {
            self.error = error
            print("Failed to delete playlist: \(error)")
        }
    }
}

// MARK: - Playlist Item Row

struct PlaylistItemRow: View {
    let item: PlaylistItem

    var body: some View {
        HStack(spacing: 12) {
            // Drag handle
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.secondary)
                .font(.caption)

            // Artwork
            AsyncImage(url: URL(string: item.artworkURL ?? "")) { image in
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
                Text(item.displayTitle)
                    .font(.headline)
                    .lineLimit(1)

                if let subtitle = item.displaySubtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let duration = item.episode?.formattedDuration {
                    Text(duration)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Position indicator
            Text("\(item.position + 1)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Edit Playlist View

struct EditPlaylistView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SyncService.self) private var syncService

    let playlist: Playlist

    @State private var name: String
    @State private var descriptionText: String
    @State private var isLoading = false
    @State private var error: Error?

    init(playlist: Playlist) {
        self.playlist = playlist
        _name = State(initialValue: playlist.name)
        _descriptionText = State(initialValue: playlist.descriptionText ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Playlist Name", text: $name)
                        .autocapitalization(.words)
                }

                Section {
                    TextField("Description (optional)", text: $descriptionText, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Edit Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await saveChanges()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                }
            }
            .alert("Error", isPresented: .init(get: { error != nil }, set: { _ in error = nil })) {
                Button("OK") {}
            } message: {
                if let error = error {
                    Text(error.localizedDescription)
                }
            }
        }
    }

    private func saveChanges() async {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            try await syncService.updatePlaylist(
                playlist,
                name: name.trimmingCharacters(in: .whitespaces),
                description: descriptionText.trimmingCharacters(in: .whitespaces).isEmpty ? nil : descriptionText
            )
            dismiss()
        } catch {
            self.error = error
        }
    }
}

// MARK: - Add to Playlist View

struct AddToPlaylistView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SyncService.self) private var syncService

    let playlist: Playlist

    @Query private var podcasts: [Podcast]
    @State private var selectedItems: Set<String> = []
    @State private var isLoading = false
    @State private var error: Error?

    private var subscribedPodcasts: [Podcast] {
        podcasts.filter { $0.isSubscribed }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(subscribedPodcasts) { podcast in
                    Section(header: Text(podcast.title)) {
                        ForEach(podcast.episodes) { episode in
                            Button {
                                toggleSelection(episode.id)
                            } label: {
                                HStack {
                                    Text(episode.title)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if selectedItems.contains(episode.id) {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Episodes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task {
                            await addSelectedItems()
                        }
                    }
                    .disabled(selectedItems.isEmpty || isLoading)
                }
            }
            .alert("Error", isPresented: .init(get: { error != nil }, set: { _ in error = nil })) {
                Button("OK") {}
            } message: {
                if let error = error {
                    Text(error.localizedDescription)
                }
            }
        }
    }

    private func toggleSelection(_ episodeId: String) {
        if selectedItems.contains(episodeId) {
            selectedItems.remove(episodeId)
        } else {
            selectedItems.insert(episodeId)
        }
    }

    private func addSelectedItems() async {
        isLoading = true
        defer { isLoading = false }

        do {
            for episodeId in selectedItems {
                // Find the episode
                let episode = podcasts
                    .flatMap { $0.episodes }
                    .first { $0.id == episodeId }

                if let episode = episode {
                    try await syncService.addToPlaylist(playlist, episode: episode)
                }
            }
            dismiss()
        } catch {
            self.error = error
        }
    }
}

#Preview {
    PlaylistDetailView(playlist: Playlist(name: "Sample Playlist"))
        .environment(SyncService.preview)
}