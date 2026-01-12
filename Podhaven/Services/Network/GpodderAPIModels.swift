import Foundation

// MARK: - Authentication

struct AuthResponse: Codable, Sendable {
    let success: Bool
    let sessionCookie: String?
    let message: String?
}

// MARK: - Subscriptions

/// Response from GET /api/2/subscriptions/{username}/{deviceid}.json
struct SubscriptionChangesResponse: Codable, Sendable {
    let add: [String]
    let remove: [String]
    let timestamp: Int64
}

struct SubscriptionUpdateRequest: Codable, Sendable {
    let add: [String]
    let remove: [String]
}

struct SubscriptionUpdateResponse: Codable, Sendable {
    let timestamp: Int64?
    let updateURLs: [[String]]?
    
    enum CodingKeys: String, CodingKey {
        case timestamp
        case updateURLs = "update_urls"
    }
}

// MARK: - Episode Actions

struct GpodderEpisodeAction: Codable, Sendable {
    let podcast: String
    let episode: String
    let action: String
    let timestamp: Date?
    let position: Int?
    let started: Int?
    let total: Int?
    let device: String?
    
    init(
        podcast: String,
        episode: String,
        action: String,
        timestamp: Date? = nil,
        position: Int? = nil,
        started: Int? = nil,
        total: Int? = nil,
        device: String? = nil
    ) {
        self.podcast = podcast
        self.episode = episode
        self.action = action
        self.timestamp = timestamp
        self.position = position
        self.started = started
        self.total = total
        self.device = device
    }
}

struct EpisodeActionsResponse: Codable, Sendable {
    let actions: [GpodderEpisodeAction]
    let timestamp: Int64
}

struct EpisodeActionsUploadResponse: Codable, Sendable {
    let timestamp: Int64?
    let updateURLs: [[String]]?
    
    enum CodingKeys: String, CodingKey {
        case timestamp
        case updateURLs = "update_urls"
    }
}

// MARK: - Device

struct GpodderDevice: Codable, Sendable {
    let id: String
    let caption: String
    let type: String
    let subscriptions: Int
}
