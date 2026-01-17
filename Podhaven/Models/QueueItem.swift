import Foundation
import SwiftData

@Model
final class QueueItem {
    @Attribute(.unique) var id: String

    var position: Int
    var episodeId: String?

    /// Server-side ID for the queue item
    var serverId: String?

    /// Relationship to episode (optional, for local reference)
    var episode: Episode?

    /// Sync state
    var needsSync: Bool
    var lastSyncedAt: Date?

    init(
        id: String = UUID().uuidString,
        position: Int,
        episodeId: String? = nil,
        serverId: String? = nil
    ) {
        self.id = id
        self.position = position
        self.episodeId = episodeId
        self.serverId = serverId
        self.needsSync = true
        self.lastSyncedAt = nil
    }
}

// MARK: - Computed Properties

extension QueueItem {
    var effectiveEpisodeId: String? {
        episodeId ?? episode?.id
    }
}