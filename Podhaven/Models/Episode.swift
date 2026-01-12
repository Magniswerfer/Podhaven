import Foundation
import SwiftData

@Model
final class Episode {
    /// Unique identifier - combination of podcast feed URL and episode GUID
    @Attribute(.unique) var id: String
    
    /// Episode metadata
    var guid: String
    var title: String
    var episodeDescription: String?
    var showNotesHTML: String?
    var audioURL: String
    var publishDate: Date?
    var duration: TimeInterval?
    var fileSize: Int64?
    var episodeNumber: Int?
    var seasonNumber: Int?
    var artworkURL: String?
    
    /// Playback state
    var playbackPosition: TimeInterval
    var isPlayed: Bool
    var lastPlayedAt: Date?
    
    /// Download state
    var downloadState: DownloadState
    var localFileURL: String?
    var downloadProgress: Double
    
    /// Sync state
    var needsSync: Bool
    var lastSyncedAt: Date?
    
    /// Relationship
    var podcast: Podcast?
    
    init(
        guid: String,
        podcastFeedURL: String,
        title: String,
        audioURL: String,
        episodeDescription: String? = nil,
        showNotesHTML: String? = nil,
        publishDate: Date? = nil,
        duration: TimeInterval? = nil,
        fileSize: Int64? = nil,
        episodeNumber: Int? = nil,
        seasonNumber: Int? = nil,
        artworkURL: String? = nil
    ) {
        self.id = "\(podcastFeedURL)|\(guid)"
        self.guid = guid
        self.title = title
        self.audioURL = audioURL
        self.episodeDescription = episodeDescription
        self.showNotesHTML = showNotesHTML
        self.publishDate = publishDate
        self.duration = duration
        self.fileSize = fileSize
        self.episodeNumber = episodeNumber
        self.seasonNumber = seasonNumber
        self.artworkURL = artworkURL
        self.playbackPosition = 0
        self.isPlayed = false
        self.lastPlayedAt = nil
        self.downloadState = .notDownloaded
        self.localFileURL = nil
        self.downloadProgress = 0
        self.needsSync = false
        self.lastSyncedAt = nil
    }
}

// MARK: - Download State

enum DownloadState: String, Codable {
    case notDownloaded
    case downloading
    case downloaded
    case failed
}

// MARK: - Computed Properties

extension Episode {
    /// URL to use for playback - local file if downloaded, otherwise remote URL
    var playbackURL: URL? {
        if downloadState == .downloaded, let localPath = localFileURL {
            return URL(fileURLWithPath: localPath)
        }
        return URL(string: audioURL)
    }
    
    /// Formatted duration string
    var formattedDuration: String? {
        guard let duration = duration else { return nil }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = duration >= 3600 ? [.hour, .minute, .second] : [.minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: duration)
    }
    
    /// Remaining time based on playback position
    var remainingTime: TimeInterval? {
        guard let duration = duration else { return nil }
        return max(0, duration - playbackPosition)
    }
    
    /// Progress as a percentage (0-1)
    var progress: Double {
        guard let duration = duration, duration > 0 else { return 0 }
        return playbackPosition / duration
    }
    
    /// Effective artwork URL - falls back to podcast artwork
    var effectiveArtworkURL: String? {
        artworkURL ?? podcast?.artworkURL
    }
}

// MARK: - Sample Data

extension Episode {
    static var sample: Episode {
        let episode = Episode(
            guid: "sample-episode-1",
            podcastFeedURL: "https://example.com/feed.xml",
            title: "Sample Episode",
            audioURL: "https://example.com/episode1.mp3",
            episodeDescription: "This is a sample episode for testing.",
            showNotesHTML: "<p>This is a sample episode for testing.</p><ul><li>Point 1</li><li>Point 2</li></ul>",
            publishDate: Date(),
            duration: 3600
        )
        return episode
    }
}
