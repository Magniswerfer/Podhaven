import SwiftUI
import WebKit
import AVKit

struct NowPlayingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AudioPlayerService.self) private var playerService
    @Environment(SyncService.self) private var syncService

    @State private var isDraggingSlider = false
    @State private var sliderValue: Double = 0
    @State private var artworkScale: CGFloat = 1.0
    @State private var scrollOffset: CGFloat = 0

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    // Animated gradient background
                    backgroundGradient

                    VStack(spacing: 0) {
                        // Scrollable content area
                        ScrollView {
                            VStack(spacing: 0) {
                                Spacer()
                                    .frame(height: 20)

                                // Artwork with glass frame
                                artworkView
                                    .frame(width: max(0, min(geometry.size.width - 64, 320)))
                                    .scaleEffect(artworkScale)
                                    .animation(.smooth(duration: 0.3), value: playerService.isPlaying)
                                    .onChange(of: playerService.isPlaying) { _, isPlaying in
                                        withAnimation(.smooth(duration: 0.3)) {
                                            artworkScale = isPlaying ? 1.0 : 0.92
                                        }
                                    }

                                Spacer()
                                    .frame(height: 24)

                                // Episode Info
                                episodeInfo
                                    .padding(.horizontal, 24)

                                // Scroll hint for show notes
                                scrollHint
                                    .padding(.top, 20)

                                // Show Notes Content (revealed by scrolling)
                                showNotesSection
                                    .padding(.top, 8)
                                    .padding(.horizontal, 16)

                                // Bottom padding for controls
                                Spacer()
                                    .frame(height: 280)
                            }
                        }
                        .scrollIndicators(.hidden)
                    }

                    // Fixed bottom controls overlay with Liquid Glass
                    VStack {
                        Spacer()
                        controlsOverlay
                    }
                }
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

                            Divider()

                            Button {
                                Task {
                                    try? await syncService.markEpisodePlayed(episode, played: !episode.isPlayed)
                                }
                            } label: {
                                Label(
                                    episode.isPlayed ? "Mark as Unplayed" : "Mark as Played",
                                    systemImage: episode.isPlayed ? "circle" : "checkmark.circle"
                                )
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .fontWeight(.semibold)
                    }
                }
            }
        }
    }

    // MARK: - Controls Overlay

    private var controlsOverlay: some View {
        VStack(spacing: 16) {
            // Progress slider
            progressView
                .padding(.horizontal, 24)

            // Main playback controls in a glass container
            controlsView

            // Extras bar
            extrasView
                .padding(.horizontal, 24)
        }
        .padding(.vertical, 24)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
        }
    }
    
    // MARK: - Background
    
    private var backgroundGradient: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.25),
                    Color.accentColor.opacity(0.1),
                    Color(.systemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Animated blur overlay
            Circle()
                .fill(Color.accentColor.opacity(0.2))
                .blur(radius: 100)
                .offset(x: -50, y: -100)
            
            Circle()
                .fill(Color.purple.opacity(0.15))
                .blur(radius: 80)
                .offset(x: 80, y: 200)
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Artwork
    
    @ViewBuilder
    private var artworkView: some View {
        if let episode = playerService.currentEpisode {
            AsyncImage(url: URL(string: episode.effectiveArtworkURL ?? "")) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(1, contentMode: .fit)
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
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.25), radius: 30, y: 15)
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
            }
        }
    }
    
    private var artworkPlaceholder: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.ultraThinMaterial)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                Image(systemName: "waveform")
                    .font(.system(size: 60, weight: .light))
                    .foregroundStyle(.secondary)
            }
    }
    
    // MARK: - Episode Info
    
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
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    // MARK: - Scroll Hint
    
    private var scrollHint: some View {
        VStack(spacing: 4) {
            Image(systemName: "chevron.down")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text("Scroll for show notes")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Show Notes Section
    
    @ViewBuilder
    private var showNotesSection: some View {
        if let episode = playerService.currentEpisode {
            VStack(alignment: .leading, spacing: 16) {
                // Section header
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundStyle(.secondary)
                    Text("Show Notes")
                        .font(.headline)
                    Spacer()
                }
                .padding(.horizontal, 8)
                
                // Show notes content
                if let html = episode.showNotesHTML, !html.isEmpty {
                    InlineShowNotesView(html: html, isDarkMode: colorScheme == .dark)
                        .frame(minHeight: 200)
                } else if let description = episode.episodeDescription, !description.isEmpty {
                    Text(description)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    Text("No show notes available for this episode.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
    }
    
    // MARK: - Progress

    private var progressView: some View {
        VStack(spacing: 8) {
            // Native slider for Liquid Glass compatibility
            Slider(
                value: Binding(
                    get: { isDraggingSlider ? sliderValue : playerService.currentTime },
                    set: { newValue in
                        isDraggingSlider = true
                        sliderValue = newValue
                    }
                ),
                in: 0...max(1, playerService.duration),
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
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                Spacer()

                Text("-" + formatTime(max(0, playerService.duration - (isDraggingSlider ? sliderValue : playerService.currentTime))))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }
    
    // MARK: - Controls

    private var controlsView: some View {
        HStack(spacing: 40) {
            // Skip backward
            Button {
                Task {
                    await playerService.skipBackward()
                }
            } label: {
                Image(systemName: "gobackward.15")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
            .frame(width: 56, height: 56)

            // Play/Pause - prominent button
            Button {
                playerService.togglePlayPause()
            } label: {
                Image(systemName: playerService.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 72, height: 72)
                    .offset(x: playerService.isPlaying ? 0 : 3)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.circle)

            // Skip forward
            Button {
                Task {
                    await playerService.skipForward()
                }
            } label: {
                Image(systemName: "goforward.30")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
            .frame(width: 56, height: 56)
        }
    }
    
    // MARK: - Extras

    private var extrasView: some View {
        HStack {
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
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)

            Spacer()

            // Sleep timer
            Button {
                // TODO: Sleep timer
            } label: {
                Image(systemName: "moon.zzz")
                    .font(.system(size: 18, weight: .medium))
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)

            Spacer()

            // AirPlay - use the native route picker
            AirPlayButton()
                .frame(width: 44, height: 44)
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

// MARK: - Inline Show Notes View (for scrollable content)

struct InlineShowNotesView: UIViewRepresentable {
    let html: String
    let isDarkMode: Bool
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.navigationDelegate = context.coordinator
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        let styledHTML = wrapHTMLWithStyles(html)
        webView.loadHTMLString(styledHTML, baseURL: nil)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    private func wrapHTMLWithStyles(_ content: String) -> String {
        let backgroundColor = isDarkMode ? "transparent" : "transparent"
        let textColor = isDarkMode ? "#ffffff" : "#000000"
        let secondaryColor = isDarkMode ? "#8e8e93" : "#6c6c70"
        let linkColor = isDarkMode ? "#0a84ff" : "#007aff"
        let codeBackground = isDarkMode ? "#2c2c2e" : "#f2f2f7"
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                * {
                    box-sizing: border-box;
                }
                
                html, body {
                    margin: 0;
                    padding: 0;
                    background-color: \(backgroundColor);
                    color: \(textColor);
                    font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif;
                    font-size: 16px;
                    line-height: 1.5;
                    -webkit-text-size-adjust: 100%;
                }
                
                body {
                    padding: 16px;
                }
                
                h1, h2, h3, h4, h5, h6 {
                    font-weight: 600;
                    margin-top: 20px;
                    margin-bottom: 10px;
                    line-height: 1.3;
                }
                
                h1 { font-size: 24px; }
                h2 { font-size: 20px; }
                h3 { font-size: 18px; }
                
                p {
                    margin: 0 0 14px 0;
                }
                
                a {
                    color: \(linkColor);
                    text-decoration: none;
                }
                
                ul, ol {
                    padding-left: 20px;
                    margin: 0 0 14px 0;
                }
                
                li {
                    margin-bottom: 6px;
                }
                
                blockquote {
                    margin: 14px 0;
                    padding: 10px 14px;
                    border-left: 3px solid \(linkColor);
                    background-color: \(codeBackground);
                    border-radius: 4px;
                }
                
                code {
                    font-family: 'SF Mono', Menlo, monospace;
                    font-size: 14px;
                    background-color: \(codeBackground);
                    padding: 2px 5px;
                    border-radius: 3px;
                }
                
                img {
                    max-width: 100%;
                    height: auto;
                    border-radius: 8px;
                    margin: 8px 0;
                }
                
                hr {
                    border: none;
                    border-top: 1px solid \(secondaryColor);
                    margin: 20px 0;
                    opacity: 0.3;
                }
            </style>
        </head>
        <body>
            \(content)
        </body>
        </html>
        """
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}



// MARK: - AirPlay Button

struct AirPlayButton: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let routePickerView = AVRoutePickerView()
        routePickerView.tintColor = UIColor.label
        routePickerView.activeTintColor = UIColor.tintColor
        routePickerView.prioritizesVideoDevices = false
        return routePickerView
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

#Preview {
    NowPlayingView()
        .environment(AudioPlayerService())
        .environment(SyncService.preview)
}
