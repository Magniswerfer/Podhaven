import AVKit
import SwiftUI

struct NowPlayingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AudioPlayerService.self) private var playerService
    @Environment(SyncService.self) private var syncService

    @State private var isDraggingSlider = false
    @State private var sliderValue: Double = 0
    @State private var artworkScale: CGFloat = 1.0

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    // Animated gradient background - extends to all edges
                    backgroundGradient

                    VStack(spacing: 0) {
                        // Drag indicator at top
                        Capsule()
                            .fill(Color.secondary.opacity(0.5))
                            .frame(width: 36, height: 5)
                            .padding(.top, 8)
                            .padding(.bottom, 4)

                        // Scrollable content area
                        ScrollView {
                            // Calculate available height above controls
                            // Controls overlay is ~220pt + safe area bottom (~34pt)
                            // Reserve space for: top padding (12) + artwork + spacing (16) + episode info (~70) + scroll hint (~50)
                            let controlsHeight: CGFloat = 254
                            let availableHeight = geometry.size.height - controlsHeight
                            let otherContentHeight: CGFloat = 148 // top padding + spacing + episode info + scroll hint
                            let maxArtworkSize = min(geometry.size.width - 64, availableHeight - otherContentHeight, 260)
                            
                            VStack(spacing: 0) {
                                Spacer()
                                    .frame(height: 12)

                                // Artwork with glass frame
                                artworkView
                                    .frame(width: max(0, maxArtworkSize))
                                    .scaleEffect(artworkScale)
                                    .onChange(of: playerService.isPlaying) { _, isPlaying in
                                        withAnimation(.easeOut(duration: 0.3)) {
                                            artworkScale = isPlaying ? 1.0 : 0.92
                                        }
                                    }

                                Spacer()
                                    .frame(height: 16)

                                // Episode Info
                                episodeInfo
                                    .padding(.horizontal, 24)

                                // Scroll hint for show notes
                                scrollHint
                                    .padding(.top, 12)

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
            .toolbarBackground(.hidden, for: .navigationBar)
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
                                    try? await syncService.markEpisodePlayed(
                                        episode, played: !episode.isPlayed)
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
        .padding(.vertical, 16)
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
                    Color(.systemBackground),
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
        .ignoresSafeArea(.all)
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
                        .scaledToFill()
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
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.25), radius: 30, y: 15)
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
            }
        }
    }

    private var artworkPlaceholder: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
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

                // Show notes content - native rendering
                if let html = episode.showNotesHTML, !html.isEmpty {
                    NativeShowNotesView(html: html)
                        .padding(16)
                        .background(
                            .ultraThinMaterial,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else if let description = episode.episodeDescription, !description.isEmpty {
                    Text(description)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            .ultraThinMaterial,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    Text("No show notes available for this episode.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .background(
                            .ultraThinMaterial,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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

                Text(
                    "-"
                        + formatTime(
                            max(
                                0,
                                playerService.duration
                                    - (isDraggingSlider ? sliderValue : playerService.currentTime)))
                )
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

// MARK: - Native Show Notes View

struct NativeShowNotesView: View {
    let html: String

    private var paragraphs: [String] {
        html.htmlToMarkdown()
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                // Handle line breaks within paragraphs
                let lines = paragraph.components(separatedBy: "\n")
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        Text(attributedLine(line))
                            .font(.body)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .tint(.accentColor)
    }

    /// Parse a line as Markdown, fallback to plain text
    private func attributedLine(_ line: String) -> AttributedString {
        if let attributed = try? AttributedString(
            markdown: line, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))
        {
            return attributed
        }
        return AttributedString(line)
    }
}

// MARK: - String HTML Extension

extension String {
    /// Convert HTML to Markdown for native SwiftUI rendering (instant, no WebKit)
    func htmlToMarkdown() -> String {
        var text = self

        // Convert links: <a href="url">text</a> -> [text](url)
        // Must be done before stripping tags
        text = text.replacingOccurrences(
            of: "<a[^>]*href=[\"']([^\"']*)[\"'][^>]*>(.*?)</a>",
            with: "[$2]($1)",
            options: .regularExpression
        )

        // Convert bold: <b>text</b>, <strong>text</strong> -> **text**
        text = text.replacingOccurrences(
            of: "<b[^>]*>(.*?)</b>",
            with: "**$1**",
            options: .regularExpression
        )
        text = text.replacingOccurrences(
            of: "<strong[^>]*>(.*?)</strong>",
            with: "**$1**",
            options: .regularExpression
        )

        // Convert italic: <i>text</i>, <em>text</em> -> *text*
        text = text.replacingOccurrences(
            of: "<i[^>]*>(.*?)</i>",
            with: "*$1*",
            options: .regularExpression
        )
        text = text.replacingOccurrences(
            of: "<em[^>]*>(.*?)</em>",
            with: "*$1*",
            options: .regularExpression
        )

        // Replace block elements with newlines
        // \n\n = paragraph break, \n = line break within paragraph
        text = text.replacingOccurrences(of: "<br[^>]*>", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "</p>", with: "\n\n", options: .caseInsensitive)
        text = text.replacingOccurrences(of: "</div>", with: "\n\n", options: .caseInsensitive)
        text = text.replacingOccurrences(of: "</li>", with: "\n", options: .caseInsensitive)
        text = text.replacingOccurrences(of: "<li[^>]*>", with: "• ", options: .regularExpression)
        text = text.replacingOccurrences(of: "</h[1-6]>", with: "\n\n", options: .regularExpression)

        // Strip all remaining HTML tags
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)

        // Decode common HTML entities
        text = text.replacingOccurrences(of: "&nbsp;", with: " ")
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        text = text.replacingOccurrences(of: "&lt;", with: "<")
        text = text.replacingOccurrences(of: "&gt;", with: ">")
        text = text.replacingOccurrences(of: "&quot;", with: "\"")
        text = text.replacingOccurrences(of: "&#39;", with: "'")
        text = text.replacingOccurrences(of: "&apos;", with: "'")
        text = text.replacingOccurrences(of: "&#x27;", with: "'")
        text = text.replacingOccurrences(of: "&mdash;", with: "—")
        text = text.replacingOccurrences(of: "&ndash;", with: "–")
        text = text.replacingOccurrences(of: "&hellip;", with: "…")

        // Clean up excessive newlines only (preserve spaces for Markdown line breaks)
        text = text.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        return text
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
