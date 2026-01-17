import Foundation
import SwiftData

/// Central dependency container for the app
@MainActor
final class AppDependencies {
    let apiClient: PodcastServiceAPIClientProtocol
    let playerService: AudioPlayerService
    let syncService: SyncService
    let downloadService: DownloadService
    
    init(modelContext: ModelContext) {
        // Initialize services with real implementations
        self.apiClient = PodcastServiceAPIClient()
        self.playerService = AudioPlayerService()
        self.downloadService = DownloadService()
        self.syncService = SyncService(
            apiClient: apiClient,
            modelContext: modelContext
        )

        // Connect player service to sync service for automatic progress tracking
        self.playerService.onPositionUpdate = { [weak self] episode, position in
            Task { @MainActor [weak self] in
                do {
                    try await self?.syncService.recordProgress(
                        episode: episode,
                        position: position,
                        completed: false
                    )
                } catch {
                    print("Failed to record progress: \(error)")
                }
            }
        }

        self.playerService.onPlaybackCompleted = { [weak self] episode in
            Task { @MainActor [weak self] in
                do {
                    try await self?.syncService.recordProgress(
                        episode: episode,
                        position: episode.duration ?? 0,
                        completed: true
                    )
                } catch {
                    print("Failed to record completion: \(error)")
                }
            }
        }
    }
    
    /// For testing/previews with mock dependencies
    init(
        apiClient: PodcastServiceAPIClientProtocol,
        playerService: AudioPlayerService,
        syncService: SyncService,
        downloadService: DownloadService
    ) {
        self.apiClient = apiClient
        self.playerService = playerService
        self.syncService = syncService
        self.downloadService = downloadService
    }
}
