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
