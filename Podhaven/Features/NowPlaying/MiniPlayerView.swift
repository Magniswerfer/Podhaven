import SwiftUI

struct MiniPlayerView: View {
    @Environment(AudioPlayerService.self) private var playerService
    
    @State private var showingFullPlayer = false
    
    var body: some View {
        if let episode = playerService.currentEpisode {
            Button {
                showingFullPlayer = true
            } label: {
                HStack(spacing: 12) {
                    // Artwork
                    AsyncImage(url: URL(string: episode.effectiveArtworkURL ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(1, contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.secondary.opacity(0.2))
                    }
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    
                    // Info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(episode.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        
                        Text(episode.podcast?.title ?? "")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Play/Pause button
                    Button {
                        playerService.togglePlayPause()
                    } label: {
                        Image(systemName: playerService.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title2)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    
                    // Skip forward
                    Button {
                        Task {
                            await playerService.skipForward()
                        }
                    } label: {
                        Image(systemName: "goforward.30")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
            }
            .buttonStyle(.plain)
            .fullScreenCover(isPresented: $showingFullPlayer) {
                NowPlayingView()
            }
        }
    }
}

#Preview {
    VStack {
        Spacer()
        MiniPlayerView()
    }
    .environment(AudioPlayerService())
}
