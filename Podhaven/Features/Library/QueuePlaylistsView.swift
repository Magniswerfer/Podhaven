import SwiftUI

struct QueuePlaylistsView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink {
                    QueueView()
                } label: {
                    Label("Listening Queue", systemImage: "list.bullet")
                }

                NavigationLink {
                    PlaylistsView()
                } label: {
                    Label("Playlists", systemImage: "music.note.list")
                }
            }
            .navigationTitle("Queue & Playlists")
        }
    }
}

#Preview {
    QueuePlaylistsView()
        .environment(SyncService.preview)
}