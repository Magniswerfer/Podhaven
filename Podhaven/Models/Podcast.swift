import Foundation
import SwiftData

@Model
final class Podcast {
    /// Unique identifier - the RSS feed URL
    @Attribute(.unique) var feedURL: String
    
    /// Podcast metadata
    var title: String
    var author: String?
    var podcastDescription: String?
    var artworkURL: String?
    var link: String?
    var language: String?
    var categories: [String]
    
    /// Local state
    var dateAdded: Date
    var lastUpdated: Date?
    var isSubscribed: Bool
    
    /// Relationships
    @Relationship(deleteRule: .cascade, inverse: \Episode.podcast)
    var episodes: [Episode]
    
    /// Sync state
    var needsSync: Bool
    var lastSyncedAt: Date?
    
    init(
        feedURL: String,
        title: String,
        author: String? = nil,
        podcastDescription: String? = nil,
        artworkURL: String? = nil,
        link: String? = nil,
        language: String? = nil,
        categories: [String] = [],
        dateAdded: Date = .now,
        isSubscribed: Bool = true
    ) {
        self.feedURL = feedURL
        self.title = title
        self.author = author
        self.podcastDescription = podcastDescription
        self.artworkURL = artworkURL
        self.link = link
        self.language = language
        self.categories = categories
        self.dateAdded = dateAdded
        self.isSubscribed = isSubscribed
        self.episodes = []
        self.needsSync = true
        self.lastSyncedAt = nil
        self.lastUpdated = nil
    }
}

// MARK: - Computed Properties

extension Podcast {
    var unplayedCount: Int {
        episodes.filter { !$0.isPlayed }.count
    }
    
    var latestEpisode: Episode? {
        episodes.sorted { ($0.publishDate ?? .distantPast) > ($1.publishDate ?? .distantPast) }.first
    }
    
    var downloadedEpisodes: [Episode] {
        episodes.filter { $0.downloadState == .downloaded }
    }
}

// MARK: - Sample Data

extension Podcast {
    static var sample: Podcast {
        Podcast(
            feedURL: "https://example.com/feed.xml",
            title: "Sample Podcast",
            author: "John Doe",
            podcastDescription: "A sample podcast for testing purposes.",
            artworkURL: "https://example.com/artwork.jpg"
        )
    }
}
