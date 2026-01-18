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

#Preview {
    RecentlyPlayedView()
        .environment(SyncService.preview)
}