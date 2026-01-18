import SwiftUI

struct MiniPlayerView: View {
    @Environment(AudioPlayerService.self) private var playerService
    
    @State private var showingFullPlayer = false
    
    private var progress: Double {
        guard playerService.duration > 0 else { return 0 }
        return playerService.currentTime / playerService.duration
    }
    
    var body: some View {
        if let episode = playerService.currentEpisode {
            VStack(spacing: 0) {
                // Progress indicator line at top
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.accentColor.opacity(0.2))
                        
                        Rectangle()
                            .fill(Color.accentColor)
                            .frame(width: geo.size.width * progress)
                    }
                }
                .frame(height: 3)
                
                // Main content
                Button {
                    showingFullPlayer = true
                } label: {
                    HStack(spacing: 12) {
                        // Artwork with subtle animation
                        AsyncImage(url: URL(string: episode.effectiveArtworkURL ?? "")) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(1, contentMode: .fill)
                            case .failure, .empty:
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(.ultraThinMaterial)
                                    .overlay {
                                        Image(systemName: "waveform")
                                            .foregroundStyle(.secondary)
                                    }
                            @unknown default:
                                Color.secondary.opacity(0.2)
                            }
                        }
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                        
                        // Info
                        VStack(alignment: .leading, spacing: 3) {
                            Text(episode.title)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                            
                            Text(episode.podcast?.title ?? "")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        
                        Spacer(minLength: 8)

                        // Play/Pause button
                        Button {
                            playerService.togglePlayPause()
                        } label: {
                            Image(systemName: playerService.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 20, weight: .medium))
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.circle)

                        // Skip forward button
                        Button {
                            Task {
                                await playerService.skipForward()
                            }
                        } label: {
                            Image(systemName: "goforward.30")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.circle)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
            .background {
                // Liquid Glass background
                ZStack {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                    
                    // Subtle gradient overlay
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.05),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
            .overlay(alignment: .top) {
                // Top border highlight
                Rectangle()
                    .fill(.white.opacity(0.15))
                    .frame(height: 0.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 12, y: -4)
            .padding(.horizontal, 8)
            .padding(.bottom, 4)
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
