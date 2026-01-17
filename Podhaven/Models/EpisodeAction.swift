import Foundation
import SwiftData

/// Represents a pending progress update for sync
/// These are queued locally and synced with the server
@Model
final class EpisodeAction {
    @Attribute(.unique) var id: String
    
    var episodeId: String
    var serverEpisodeId: String?
    var timestamp: Date
    var positionSeconds: Int
    var durationSeconds: Int
    var completed: Bool
    
    /// Sync state
    var isSynced: Bool
    var syncAttempts: Int
    var lastSyncError: String?
    
    init(
        episodeId: String,
        serverEpisodeId: String?,
        positionSeconds: Int,
        durationSeconds: Int,
        completed: Bool,
        timestamp: Date = .now
    ) {
        self.id = UUID().uuidString
        self.episodeId = episodeId
        self.serverEpisodeId = serverEpisodeId
        self.positionSeconds = positionSeconds
        self.durationSeconds = durationSeconds
        self.completed = completed
        self.timestamp = timestamp
        self.isSynced = false
        self.syncAttempts = 0
        self.lastSyncError = nil
    }
}

// MARK: - Conversion to API model

extension EpisodeAction {
    /// Convert to bulk progress update format
    func toBulkProgressUpdate() -> BulkProgressUpdate? {
        guard let serverEpisodeId = serverEpisodeId else { return nil }
        return BulkProgressUpdate(
            episodeId: serverEpisodeId,
            positionSeconds: positionSeconds,
            durationSeconds: durationSeconds,
            completed: completed
        )
    }
}
