import SwiftUI

struct NowPlayingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AudioPlayerService.self) private var playerService
    
    @State private var isDraggingSlider = false
    @State private var sliderValue: Double = 0
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                VStack(spacing: 24) {
                    Spacer()
                    
                    // Artwork
                    artworkView
                        .frame(width: geometry.size.width - 80)
                    
                    Spacer()
                    
                    // Episode Info
                    episodeInfo
                    
                    // Progress
                    progressView
                    
                    // Controls
                    controlsView
                    
                    // Speed & extras
                    extrasView
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                            .fontWeight(.semibold)
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if let episode = playerService.currentEpisode {
                            Button {
                                // Share
                            } label: {
                                Label("Share Episode", systemImage: "square.and.arrow.up")
                            }
                            
                            Button {
                                episode.isPlayed.toggle()
                            } label: {
                                Label(
                                    episode.isPlayed ? "Mark as Unplayed" : "Mark as Played",
                                    systemImage: episode.isPlayed ? "circle" : "checkmark.circle"
                                )
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .background(
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.15), Color(.systemBackground)],
                    startPoint: .top,
                    endPoint: .center
                )
                .ignoresSafeArea()
            )
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var artworkView: some View {
        if let episode = playerService.currentEpisode {
            AsyncImage(url: URL(string: episode.effectiveArtworkURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
            } placeholder: {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.secondary.opacity(0.2))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        Image(systemName: "waveform")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                    }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
        }
    }
    
    @ViewBuilder
    private var episodeInfo: some View {
        if let episode = playerService.currentEpisode {
            VStack(spacing: 8) {
                Text(episode.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                Text(episode.podcast?.title ?? "")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var progressView: some View {
        VStack(spacing: 8) {
            // Slider
            Slider(
                value: Binding(
                    get: { isDraggingSlider ? sliderValue : playerService.currentTime },
                    set: { newValue in
                        sliderValue = newValue
                        isDraggingSlider = true
                    }
                ),
                in: 0...max(playerService.duration, 1),
                onEditingChanged: { editing in
                    if !editing {
                        Task {
                            await playerService.seek(to: sliderValue)
                            isDraggingSlider = false
                        }
                    }
                }
            )
            .tint(.accentColor)
            
            // Time labels
            HStack {
                Text(formatTime(isDraggingSlider ? sliderValue : playerService.currentTime))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                
                Spacer()
                
                Text("-" + formatTime(max(0, playerService.duration - (isDraggingSlider ? sliderValue : playerService.currentTime))))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }
    
    private var controlsView: some View {
        HStack(spacing: 40) {
            // Skip backward
            Button {
                Task {
                    await playerService.skipBackward()
                }
            } label: {
                Image(systemName: "gobackward.15")
                    .font(.system(size: 32))
            }
            .buttonStyle(.plain)
            
            // Play/Pause
            Button {
                playerService.togglePlayPause()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 72, height: 72)
                    
                    Image(systemName: playerService.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(.white)
                        .offset(x: playerService.isPlaying ? 0 : 2)
                }
            }
            .buttonStyle(.plain)
            
            // Skip forward
            Button {
                Task {
                    await playerService.skipForward()
                }
            } label: {
                Image(systemName: "goforward.30")
                    .font(.system(size: 32))
            }
            .buttonStyle(.plain)
        }
    }
    
    private var extrasView: some View {
        HStack(spacing: 48) {
            // Playback speed
            Menu {
                ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0], id: \.self) { speed in
                    Button {
                        playerService.setPlaybackRate(Float(speed))
                    } label: {
                        HStack {
                            Text("\(speed, specifier: "%.2g")x")
                            if playerService.playbackRate == Float(speed) {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Text("\(playerService.playbackRate, specifier: "%.2g")x")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            
            // Sleep timer placeholder
            Button {
                // TODO: Sleep timer
            } label: {
                Image(systemName: "moon.zzz")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            
            // AirPlay
            Button {
                // TODO: AirPlay picker
            } label: {
                Image(systemName: "airplayaudio")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Helpers
    
    private func formatTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = Int(time) / 60 % 60
        let seconds = Int(time) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    NowPlayingView()
        .environment(AudioPlayerService())
}
