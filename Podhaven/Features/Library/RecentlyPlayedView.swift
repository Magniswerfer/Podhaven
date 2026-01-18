import SwiftUI

struct RecentlyPlayedView: View {
    @Environment(SyncService.self) private var syncService
    @State private var recentlyPlayed: [ProgressRecord] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text("Failed to load recently played")
                            .font(.headline)
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            Task {
                                await loadRecentlyPlayed()
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                } else if recentlyPlayed.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "headphones")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No recently played episodes")
                            .font(.headline)
                        Text("Episodes you've listened to will appear here")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    List(recentlyPlayed) { record in
                        RecentlyPlayedRow(record: record)
                            .contentShape(Rectangle())
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Recently Played")
            .refreshable {
                await loadRecentlyPlayed()
            }
        }
        .task {
            await loadRecentlyPlayed()
        }
    }

    private func loadRecentlyPlayed() async {
        isLoading = true
        errorMessage = nil

        do {
            let progressResponse = try await syncService.getProgress()
            recentlyPlayed = progressResponse.progress
                .sorted(by: { $0.lastUpdatedAt > $1.lastUpdatedAt })
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

struct RecentlyPlayedRow: View {
    let record: ProgressRecord

    var body: some View {
        HStack(spacing: 12) {
            // Podcast artwork placeholder (progress records don't include artwork)
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "headphones")
                        .foregroundColor(.secondary)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(record.episode?.title ?? "Unknown Episode")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text(record.episode?.podcast?.title ?? "Unknown Podcast")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                // Progress indicator
                if record.durationSeconds > 0 {
                    let progress = min(Double(record.positionSeconds) / Double(record.durationSeconds), 1.0)
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 3)
                            Rectangle()
                                .fill(Color.accentColor)
                                .frame(width: geometry.size.width * progress, height: 3)
                        }
                    }
                    .frame(height: 3)
                }

                Text(formatProgress(record.positionSeconds, total: record.durationSeconds))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private func formatProgress(_ position: Int, total: Int) -> String {
        let positionTime = formatTime(TimeInterval(position))
        let totalTime = formatTime(TimeInterval(total))
        return "\(positionTime) / \(totalTime)"
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    RecentlyPlayedView()
        .environment(SyncService.preview)
}