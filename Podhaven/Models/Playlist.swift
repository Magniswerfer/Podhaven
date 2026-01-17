import Foundation
import SwiftData

@Model
final class Playlist {
    @Attribute(.unique) var id: String

    /// Server-side ID for the playlist
    var serverId: String?

    var name: String
    var descriptionText: String?

    var createdAt: Date
    var updatedAt: Date

    /// Relationships
    @Relationship(deleteRule: .cascade, inverse: \PlaylistItem.playlist)
    var items: [PlaylistItem]

    /// Sync state
    var needsSync: Bool
    var lastSyncedAt: Date?

    init(
        id: String = UUID().uuidString,
        serverId: String? = nil,
        name: String,
        descriptionText: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.serverId = serverId
        self.name = name
        self.descriptionText = descriptionText
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.items = []
        self.needsSync = true
        self.lastSyncedAt = nil
    }
}

// MARK: - Computed Properties

extension Playlist {
    var itemCount: Int {
        items.count
    }

    var sortedItems: [PlaylistItem] {
        items.sorted { $0.position < $1.position }
    }
}