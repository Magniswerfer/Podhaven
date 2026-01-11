import Foundation
import SwiftData

/// Represents an episode action for gpodder sync
/// These are queued locally and synced with the server
@Model
final class EpisodeAction {
    @Attribute(.unique) var id: String
    
    var podcastURL: String
    var episodeURL: String
    var action: ActionType
    var timestamp: Date
    var position: TimeInterval?
    var total: TimeInterval?
    var started: TimeInterval?
    
    /// Sync state
    var isSynced: Bool
    var syncAttempts: Int
    var lastSyncError: String?
    
    init(
        podcastURL: String,
        episodeURL: String,
        action: ActionType,
        timestamp: Date = .now,
        position: TimeInterval? = nil,
        total: TimeInterval? = nil,
        started: TimeInterval? = nil
    ) {
        self.id = UUID().uuidString
        self.podcastURL = podcastURL
        self.episodeURL = episodeURL
        self.action = action
        self.timestamp = timestamp
        self.position = position
        self.total = total
        self.started = started
        self.isSynced = false
        self.syncAttempts = 0
        self.lastSyncError = nil
    }
}

// MARK: - Action Type

enum ActionType: String, Codable {
    case play
    case download
    case delete
    case new
}

// MARK: - API Conversion

extension EpisodeAction {
    /// Convert to API request format
    var apiRepresentation: [String: Any] {
        var dict: [String: Any] = [
            "podcast": podcastURL,
            "episode": episodeURL,
            "action": action.rawValue,
            "timestamp": ISO8601DateFormatter().string(from: timestamp)
        ]
        
        if let position = position {
            dict["position"] = Int(position)
        }
        if let total = total {
            dict["total"] = Int(total)
        }
        if let started = started {
            dict["started"] = Int(started)
        }
        
        return dict
    }
    
    /// Create from API response
    static func from(apiResponse: GpodderEpisodeAction, modelContext: ModelContext) -> EpisodeAction {
        EpisodeAction(
            podcastURL: apiResponse.podcast,
            episodeURL: apiResponse.episode,
            action: ActionType(rawValue: apiResponse.action) ?? .play,
            timestamp: apiResponse.timestamp ?? .now,
            position: apiResponse.position.map { TimeInterval($0) },
            total: apiResponse.total.map { TimeInterval($0) },
            started: apiResponse.started.map { TimeInterval($0) }
        )
    }
}
