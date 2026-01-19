import SwiftUI

// MARK: - Linear Progress Bar

/// A linear progress bar with capsule shape and accent color fill
struct ProgressBar: View {
    /// Progress value from 0.0 to 1.0
    var progress: Double

    /// Height of the progress bar
    var height: CGFloat = 3

    /// Fill color for the progress
    var fillColor: Color = Color.Podhaven.accent

    /// Track color (background)
    var trackColor: Color = Color.secondary.opacity(0.2)

    /// Whether to animate progress changes
    var animated: Bool = true

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(trackColor)

                Capsule()
                    .fill(fillColor)
                    .frame(width: geo.size.width * min(max(progress, 0), 1))
            }
        }
        .frame(height: height)
        .animation(animated ? .smooth(duration: AnimationDuration.normal) : nil, value: progress)
    }
}

// MARK: - Thin Progress Line

/// A thin progress line for use at the top of containers (like mini player)
struct ProgressLine: View {
    var progress: Double
    var fillColor: Color = Color.Podhaven.accent
    var trackColor: Color = Color.Podhaven.accent.opacity(0.2)
    var height: CGFloat = 3

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(trackColor)

                Rectangle()
                    .fill(fillColor)
                    .frame(width: geo.size.width * min(max(progress, 0), 1))
            }
        }
        .frame(height: height)
    }
}

#Preview {
    VStack(spacing: 20) {
        Text("Progress: 25%")
        ProgressBar(progress: 0.25)

        Text("Progress: 50%")
        ProgressBar(progress: 0.5, height: 6)

        Text("Progress: 75%")
        ProgressBar(progress: 0.75, fillColor: .green)

        Text("Progress Line")
        ProgressLine(progress: 0.6)
    }
    .padding()
}
