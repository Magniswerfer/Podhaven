import Foundation
import SwiftData

@Model
final class PlaylistItem {
    @Attribute(.unique) var id: String

    /// Server-side ID for the playlist item
    var serverId: String?

    var position: Int

    /// Either a podcast or episode can be added to a playlist
    var podcastId: String?
    var episodeId: String?

    /// Relationships (optional for local reference)
    var podcast: Podcast?
    var episode: Episode?

    /// Relationship back to playlist
    var playlist: Playlist?

    /// Sync state
    var needsSync: Bool
    var lastSyncedAt: Date?

    init(
        id: String = UUID().uuidString,
        serverId: String? = nil,
        position: Int,
        podcastId: String? = nil,
        episodeId: String? = nil
    ) {
        self.id = id
        self.serverId = serverId
        self.position = position
        self.podcastId = podcastId
        self.episodeId = episodeId
        self.needsSync = true
        self.lastSyncedAt = nil
    }
}

// MARK: - Computed Properties

extension PlaylistItem {
    var effectivePodcastId: String? {
        podcastId ?? podcast?.feedURL
    }

    var effectiveEpisodeId: String? {
        episodeId ?? episode?.id
    }

    var displayTitle: String {
        if let episode = episode {
            return episode.title
        } else if let podcast = podcast {
            return podcast.title
        } else {
            return "Unknown Item"
        }
    }

    var displaySubtitle: String? {
        if let episode = episode, let podcast = episode.podcast {
            return podcast.title
        } else if let podcast = podcast {
            return podcast.author
        }
        return nil
    }

    var artworkURL: String? {
        episode?.effectiveArtworkURL ?? podcast?.artworkURL
    }
}