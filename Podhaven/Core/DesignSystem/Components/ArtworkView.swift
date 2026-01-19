import SwiftUI

// MARK: - Artwork Size

/// Predefined artwork sizes for consistency
enum ArtworkSize {
    /// 48pt - Small thumbnails in lists
    case small

    /// 56pt - Episode row thumbnails
    case episodeRow

    /// 64pt - Search results
    case searchResult

    /// 120pt - Continue listening cards
    case card

    /// 150pt - Grid items
    case grid

    /// Variable - Large artwork in now playing
    case large

    var dimension: CGFloat {
        switch self {
        case .small: return 48
        case .episodeRow: return 56
        case .searchResult: return 64
        case .card: return 120
        case .grid: return 150
        case .large: return 320
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .small, .episodeRow, .searchResult:
            return CornerRadius.small
        case .card, .grid:
            return CornerRadius.medium
        case .large:
            return CornerRadius.large
        }
    }
}

// MARK: - Artwork View

/// A consistent artwork view with placeholder and optional progress overlay
struct ArtworkView: View {
    var url: String?
    var size: ArtworkSize = .card
    var progress: Double? = nil
    var isPlaying: Bool = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Artwork image
            if let urlString = url, let imageURL = URL(string: urlString) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(1, contentMode: .fill)
                    case .failure:
                        placeholder
                    case .empty:
                        placeholder
                            .overlay {
                                ProgressView()
                            }
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }

            // Playing indicator overlay
            if isPlaying {
                Color.black.opacity(0.4)
                Image(systemName: "waveform")
                    .font(size == .large ? .largeTitle : .title3)
                    .foregroundStyle(.white)
                    .symbolEffect(.variableColor.iterative)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Progress overlay
            if let progress = progress, progress > 0 && progress < 1 {
                ThumbnailProgressOverlay(
                    progress: progress,
                    size: progressOverlaySize
                )
                .padding(Spacing.sm)
            }
        }
        .frame(width: size.dimension, height: size.dimension)
        .clipShape(RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous))
        .subtleShadow()
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
            .fill(Color.secondary.opacity(0.2))
            .overlay {
                Image(systemName: "waveform")
                    .font(placeholderIconSize)
                    .foregroundStyle(.secondary)
            }
    }

    private var placeholderIconSize: Font {
        switch size {
        case .small, .episodeRow, .searchResult:
            return .body
        case .card:
            return .title2
        case .grid:
            return .title
        case .large:
            return .largeTitle
        }
    }

    private var progressOverlaySize: CGFloat {
        switch size {
        case .small, .episodeRow, .searchResult:
            return 24
        case .card, .grid:
            return 32
        case .large:
            return 44
        }
    }
}

// MARK: - Flexible Artwork View

/// An artwork view that adapts to its container size
struct FlexibleArtworkView: View {
    var url: String?
    var cornerRadius: CGFloat = CornerRadius.medium
    var showPlaceholder: Bool = true

    var body: some View {
        Group {
            if let urlString = url, let imageURL = URL(string: urlString) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(1, contentMode: .fill)
                    case .failure:
                        if showPlaceholder { placeholder }
                    case .empty:
                        if showPlaceholder {
                            placeholder
                                .overlay { ProgressView() }
                        }
                    @unknown default:
                        if showPlaceholder { placeholder }
                    }
                }
            } else if showPlaceholder {
                placeholder
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.secondary.opacity(0.2))
            .overlay {
                Image(systemName: "waveform")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            Text("Small (48pt)")
            ArtworkView(size: .small)

            Text("Episode Row (56pt)")
            ArtworkView(size: .episodeRow, isPlaying: true)

            Text("Search Result (64pt)")
            ArtworkView(size: .searchResult, progress: 0.45)

            Text("Card (120pt)")
            ArtworkView(size: .card, progress: 0.7)

            Text("Grid (150pt)")
            ArtworkView(size: .grid)

            Text("Flexible (fits container)")
            FlexibleArtworkView()
                .frame(width: 200)
        }
        .padding()
    }
}
