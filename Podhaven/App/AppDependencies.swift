import Foundation
import SwiftData

/// Central dependency container for the app
@MainActor
final class AppDependencies {
    let apiClient: GpodderAPIClientProtocol
    let playerService: AudioPlayerService
    let syncService: SyncService
    let downloadService: DownloadService
    
    init(modelContext: ModelContext) {
        // Initialize services with real implementations
        self.apiClient = GpodderAPIClient()
        self.playerService = AudioPlayerService()
        self.downloadService = DownloadService()
        self.syncService = SyncService(
            apiClient: apiClient,
            modelContext: modelContext
        )
    }
    
    /// For testing/previews with mock dependencies
    init(
        apiClient: GpodderAPIClientProtocol,
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
