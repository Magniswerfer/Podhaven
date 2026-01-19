import SwiftUI

// MARK: - Circular Progress View

/// A circular progress indicator
struct CircularProgressView: View {
    /// Progress value from 0.0 to 1.0
    var progress: Double

    /// Line width of the progress ring
    var lineWidth: CGFloat = 3

    /// Color of the progress fill
    var fillColor: Color = .white

    /// Color of the track (background ring)
    var trackColor: Color = Color.black.opacity(0.2)

    /// Whether to animate progress changes
    var animated: Bool = true

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(trackColor, lineWidth: lineWidth)

            // Progress
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(fillColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .animation(animated ? .smooth(duration: AnimationDuration.normal) : nil, value: progress)
    }
}

// MARK: - Circular Progress with Label

/// A circular progress indicator with a centered label
struct LabeledCircularProgress: View {
    var progress: Double
    var lineWidth: CGFloat = 4
    var fillColor: Color = Color.Podhaven.accent
    var trackColor: Color = Color.secondary.opacity(0.2)

    /// Whether to show percentage label in center
    var showLabel: Bool = true

    var body: some View {
        ZStack {
            CircularProgressView(
                progress: progress,
                lineWidth: lineWidth,
                fillColor: fillColor,
                trackColor: trackColor
            )

            if showLabel {
                Text("\(Int(progress * 100))%")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .monospacedDigit()
            }
        }
    }
}

// MARK: - Thumbnail Progress Overlay

/// A circular progress overlay designed to sit on thumbnails
struct ThumbnailProgressOverlay: View {
    var progress: Double
    var size: CGFloat = 32

    var body: some View {
        CircularProgressView(
            progress: progress,
            lineWidth: 3,
            fillColor: .white,
            trackColor: .black.opacity(0.2)
        )
        .frame(width: size, height: size)
        .background(.black.opacity(0.3), in: Circle())
    }
}

#Preview {
    VStack(spacing: 30) {
        HStack(spacing: 20) {
            CircularProgressView(progress: 0.25)
                .frame(width: 40, height: 40)

            CircularProgressView(progress: 0.5, fillColor: Color.Podhaven.accent)
                .frame(width: 40, height: 40)

            CircularProgressView(progress: 0.75, fillColor: .green)
                .frame(width: 40, height: 40)
        }

        LabeledCircularProgress(progress: 0.67)
            .frame(width: 60, height: 60)

        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(.secondary.opacity(0.3))
                .frame(width: 120, height: 120)

            ThumbnailProgressOverlay(progress: 0.45)
                .padding(8)
        }
    }
    .padding()
}
