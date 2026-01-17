import Foundation

// MARK: - Authentication

struct AuthRequest: Codable, Sendable {
    let email: String
    let password: String?
}

struct AuthResponse: Codable, Sendable {
    let user: AuthUser
}

struct AuthUser: Codable, Sendable {
    let id: String
    let email: String
    let apiKey: String
}

// MARK: - Profile

struct ProfileResponse: Codable, Sendable {
    let id: String
    let email: String
    let apiKey: String
    let fullApiKey: String?
    let defaultSettings: ProfileSettings?
    let createdAt: Date
    let hasPassword: Bool
}

struct ProfileSettings: Codable, Sendable {
    let episodeFilter: String?
    let episodeSort: String?
    let dateFormat: String?
}

// MARK: - Podcasts

struct PodcastsResponse: Codable, Sendable {
    let podcasts: [SubscribedPodcast]
}

struct SubscribedPodcast: Codable, Sendable {
    let id: String
    let title: String
    let description: String?
    let feedUrl: String
    let artworkUrl: String?
    let author: String?
    let subscribedAt: Date
    let episodeCount: Int?
    let customSettings: PodcastCustomSettings?
}

struct PodcastCustomSettings: Codable, Sendable {
    let episodeFilter: String?
    let episodeSort: String?
}

struct SubscribeRequest: Codable, Sendable {
    let feedUrl: String
}

struct SubscribeResponse: Codable, Sendable {
    let podcast: SubscribedPodcastBasic
}

struct SubscribedPodcastBasic: Codable, Sendable {
    let id: String
    let title: String
    let subscribedAt: Date
    let episodeCount: Int?
}

struct UnsubscribeResponse: Codable, Sendable {
    let success: Bool
}

// MARK: - Podcast Search

struct PodcastSearchResponse: Codable, Sendable {
    let results: [PodcastSearchResult]
    let count: Int
}

struct PodcastSearchResult: Codable, Sendable {
    let title: String
    let feedUrl: String
    let artworkUrl: String?
    let author: String?
}

// MARK: - Episodes

struct EpisodesResponse: Codable, Sendable {
    let episodes: [APIEpisode]
    let total: Int
    let limit: Int
    let offset: Int
}

struct APIEpisode: Codable, Sendable {
    let id: String
    let title: String
    let description: String?
    let audioUrl: String
    let publishedAt: Date?
    let durationSeconds: Int?
    let artworkUrl: String?
    let podcast: APIPodcastBasic?
    let progress: APIProgress?
}

struct APIPodcastBasic: Codable, Sendable {
    let id: String
    let title: String
    let artworkUrl: String?
}

struct EpisodeDetailResponse: Codable, Sendable {
    let id: String
    let title: String
    let description: String?
    let audioUrl: String
    let publishedAt: Date?
    let durationSeconds: Int?
    let artworkUrl: String?
    let podcast: APIPodcastBasic?
    let progress: APIProgressDetail?
}

// MARK: - Progress

struct ProgressResponse: Codable, Sendable {
    let progress: [ProgressRecord]
}

struct ProgressRecord: Codable, Sendable {
    let id: String
    let episodeId: String
    let positionSeconds: Int
    let durationSeconds: Int
    let completed: Bool
    let lastUpdatedAt: Date
    let episode: ProgressEpisode?
}

struct ProgressEpisode: Codable, Sendable {
    let id: String
    let title: String
    let podcast: ProgressPodcast?
}

struct ProgressPodcast: Codable, Sendable {
    let id: String
    let title: String
}

struct APIProgress: Codable, Sendable {
    let positionSeconds: Int
    let durationSeconds: Int?
    let completed: Bool
}

struct APIProgressDetail: Codable, Sendable {
    let positionSeconds: Int
    let durationSeconds: Int
    let completed: Bool
    let lastUpdatedAt: Date
}

struct ProgressUpdateRequest: Codable, Sendable {
    let positionSeconds: Int
    let durationSeconds: Int
    let completed: Bool
}

struct ProgressUpdateResponse: Codable, Sendable {
    let progress: ProgressRecord
}

struct BulkProgressUpdateRequest: Codable, Sendable {
    let updates: [BulkProgressUpdate]
}

struct BulkProgressUpdate: Codable, Sendable {
    let episodeId: String
    let positionSeconds: Int
    let durationSeconds: Int
    let completed: Bool
}

struct BulkProgressUpdateResponse: Codable, Sendable {
    let results: [BulkProgressResult]
}

struct BulkProgressResult: Codable, Sendable {
    let episodeId: String
    let success: Bool
    let progress: ProgressRecord?
    let error: String?
}

// MARK: - Queue

struct QueueResponse: Codable, Sendable {
    let queue: [APIModelQueueItem]
}

struct APIModelQueueItem: Codable, Sendable {
    let id: String
    let episodeId: String
    let position: Int
    let episode: QueueEpisode?
}

struct QueueEpisode: Codable, Sendable {
    let id: String
    let title: String
    let audioUrl: String
    let podcast: APIPodcastBasic?
    let progress: APIProgress?
}

struct AddToQueueRequest: Codable, Sendable {
    let episodeId: String
}

struct AddToQueueResponse: Codable, Sendable {
    let queueItem: APIModelQueueItem
    let queue: [APIModelQueueItem]
}

struct QueueReorderItem: Codable, Sendable {
    let id: String
    let position: Int
}

struct QueueReorderRequest: Codable, Sendable {
    let items: [QueueReorderItem]
}

// MARK: - Playlists

struct PlaylistsResponse: Codable, Sendable {
    let playlists: [APIPlaylist]
}

struct APIPlaylist: Codable, Sendable {
    let id: String
    let name: String
    let description: String?
    let createdAt: Date
    let updatedAt: Date
    let _count: PlaylistCount?
}

struct PlaylistCount: Codable, Sendable {
    let items: Int
}

struct CreatePlaylistRequest: Codable, Sendable {
    let name: String
    let description: String?
}

struct UpdatePlaylistRequest: Codable, Sendable {
    let name: String?
    let description: String?
}

struct CreatePlaylistResponse: Codable, Sendable {
    let playlist: APIPlaylist
}

struct PlaylistDetailResponse: Codable, Sendable {
    let playlist: APIPlaylistWithItems
}

struct APIPlaylistWithItems: Codable, Sendable {
    let id: String
    let name: String
    let description: String?
    let createdAt: Date
    let updatedAt: Date
    let items: [APIModelPlaylistItem]
}

struct APIModelPlaylistItem: Codable, Sendable {
    let id: String
    let position: Int
    let podcast: APIPodcastBasic?
    let episode: PlaylistEpisode?
}

struct PlaylistEpisode: Codable, Sendable {
    let id: String
    let title: String
    let podcast: APIPodcastBasic?
}

struct AddToPlaylistRequest: Codable, Sendable {
    let podcastId: String?
    let episodeId: String?
    let position: Int?
}

struct UpdatePlaylistItemRequest: Codable, Sendable {
    let position: Int
}

// MARK: - Stats

struct DashboardStatsResponse: Codable, Sendable {
    let stats: DashboardStats
}

struct DashboardStats: Codable, Sendable {
    let totalListeningTimeSeconds: Int
    let totalEpisodesCompleted: Int
    let totalEpisodesInProgress: Int
    let totalPodcastsSubscribed: Int
}

// MARK: - Error Response

struct APIErrorResponse: Codable, Sendable {
    let error: String
    let details: APIErrorDetails?
}

struct APIErrorDetails: Codable, Sendable {
    // Validation error details can vary, so we use a generic approach
    let message: String?
}
