import SwiftUI
import SwiftData

struct PlaylistsView: View {
    @Environment(SyncService.self) private var syncService
    @Query private var playlists: [Playlist]

    @State private var isLoading = false
    @State private var showingCreatePlaylist = false
    @State private var error: Error?

    var body: some View {
        NavigationStack {
            Group {
                if playlists.isEmpty && !isLoading {
                    emptyPlaylistsView
                } else {
                    playlistsList
                }
            }
            .navigationTitle("Playlists")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingCreatePlaylist = true
                    } label: {
                        Image(systemName: "plus")
                    }
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
            // Artwork placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.2))
                .frame(width: 48, height: 48)
                .overlay {
                    Image(systemName: "music.note.list")
                        .foregroundStyle(.secondary)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(playlist.name)
                    .font(.headline)
                    .lineLimit(1)

                if let description = playlist.descriptionText {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text("\(playlist.itemCount) episodes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Create Playlist View

struct CreatePlaylistView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SyncService.self) private var syncService

    @State private var name = ""
    @State private var descriptionText = ""
    @State private var isLoading = false
    @State private var error: Error?

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
            .navigationTitle("Create Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            await createPlaylist()
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

    private func createPlaylist() async {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            _ = try await syncService.createPlaylist(
                name: name.trimmingCharacters(in: .whitespaces),
                description: descriptionText.trimmingCharacters(in: .whitespaces).isEmpty ? nil : descriptionText
            )
            dismiss()
        } catch {
            self.error = error
        }
    }
}

#Preview {
    PlaylistsView()
        .environment(SyncService.preview)
}