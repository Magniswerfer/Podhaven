import Foundation

// MARK: - Protocol

/// Protocol defining the podcast service API interface for dependency injection and testing
protocol PodcastServiceAPIClientProtocol: Sendable {
    /// Register a new user account
    func register(
        serverURL: String,
        email: String,
        password: String?
    ) async throws -> AuthResponse
    
    /// Authenticate with the server
    func login(
        serverURL: String,
        email: String,
        password: String?
    ) async throws -> AuthResponse
    
    /// Get user's podcast subscriptions
    func getSubscriptions(
        serverURL: String,
        apiKey: String
    ) async throws -> PodcastsResponse
    
    /// Subscribe to a podcast by RSS feed URL
    func subscribe(
        serverURL: String,
        apiKey: String,
        feedURL: String
    ) async throws -> SubscribeResponse
    
    /// Unsubscribe from a podcast
    func unsubscribe(
        serverURL: String,
        apiKey: String,
        podcastId: String
    ) async throws -> UnsubscribeResponse
    
    /// Refresh a podcast feed
    func refreshPodcast(
        serverURL: String,
        apiKey: String,
        podcastId: String
    ) async throws
    
    /// Search for podcasts
    func searchPodcasts(
        serverURL: String,
        apiKey: String,
        query: String,
        limit: Int?
    ) async throws -> PodcastSearchResponse
    
    /// Get episodes for a podcast
    func getEpisodes(
        serverURL: String,
        apiKey: String,
        podcastId: String?,
        limit: Int?,
        offset: Int?,
        filter: String?,
        sort: String?
    ) async throws -> EpisodesResponse
    
    /// Get all listening progress
    func getProgress(
        serverURL: String,
        apiKey: String
    ) async throws -> ProgressResponse
    
    /// Update listening progress for a single episode
    func updateProgress(
        serverURL: String,
        apiKey: String,
        episodeId: String,
        positionSeconds: Int,
        durationSeconds: Int,
        completed: Bool
    ) async throws -> ProgressUpdateResponse
    
    /// Bulk update listening progress
    func bulkUpdateProgress(
        serverURL: String,
        apiKey: String,
        updates: [BulkProgressUpdate]
    ) async throws -> BulkProgressUpdateResponse

    /// Get listening queue
    func getQueue(
        serverURL: String,
        apiKey: String
    ) async throws -> QueueResponse

    /// Add episode to queue
    func addToQueue(
        serverURL: String,
        apiKey: String,
        episodeId: String
    ) async throws -> AddToQueueResponse

    /// Reorder queue items
    func reorderQueue(
        serverURL: String,
        apiKey: String,
        items: [QueueReorderItem]
    ) async throws -> QueueResponse

    /// Clear queue (optionally preserve current episode)
    func clearQueue(
        serverURL: String,
        apiKey: String,
        currentEpisodeId: String?
    ) async throws -> QueueResponse

    /// Remove item from queue
    func removeFromQueue(
        serverURL: String,
        apiKey: String,
        queueItemId: String
    ) async throws -> UnsubscribeResponse

    /// Get all playlists
    func getPlaylists(
        serverURL: String,
        apiKey: String
    ) async throws -> PlaylistsResponse

    /// Create playlist
    func createPlaylist(
        serverURL: String,
        apiKey: String,
        name: String,
        description: String?
    ) async throws -> CreatePlaylistResponse

    /// Get playlist with items
    func getPlaylist(
        serverURL: String,
        apiKey: String,
        playlistId: String
    ) async throws -> PlaylistDetailResponse

    /// Update playlist
    func updatePlaylist(
        serverURL: String,
        apiKey: String,
        playlistId: String,
        name: String?,
        description: String?
    ) async throws -> APIPlaylist

    /// Delete playlist
    func deletePlaylist(
        serverURL: String,
        apiKey: String,
        playlistId: String
    ) async throws -> UnsubscribeResponse

    /// Add item to playlist
    func addToPlaylist(
        serverURL: String,
        apiKey: String,
        playlistId: String,
        podcastId: String?,
        episodeId: String?,
        position: Int?
    ) async throws -> APIModelPlaylistItem

    /// Update playlist item position
    func updatePlaylistItem(
        serverURL: String,
        apiKey: String,
        playlistId: String,
        itemId: String,
        position: Int
    ) async throws

    /// Remove item from playlist
    func removeFromPlaylist(
        serverURL: String,
        apiKey: String,
        playlistId: String,
        itemId: String
    ) async throws -> UnsubscribeResponse
}

// MARK: - Implementation

final class PodcastServiceAPIClient: PodcastServiceAPIClientProtocol, Sendable {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    
    init(session: URLSession = .shared) {
        self.session = session
        
        self.decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            // Try ISO8601 with fractional seconds first
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = isoFormatter.date(from: dateString) {
                return date
            }
            
            // Try ISO8601 without fractional seconds
            isoFormatter.formatOptions = [.withInternetDateTime]
            if let date = isoFormatter.date(from: dateString) {
                return date
            }
            
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Invalid date format: \(dateString)")
            )
        }
        
        self.encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
    }
    
    // MARK: - Authentication
    
    func register(
        serverURL: String,
        email: String,
        password: String?
    ) async throws -> AuthResponse {
        guard let url = URL(string: "\(serverURL)/api/auth/register") else {
            throw PodcastServiceAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = AuthRequest(email: email, password: password)
        request.httpBody = try encoder.encode(body)
        
        let (data, response) = try await session.data(for: request)
        
        try validateResponse(response, data: data)
        
        return try decoder.decode(AuthResponse.self, from: data)
    }
    
    func login(
        serverURL: String,
        email: String,
        password: String?
    ) async throws -> AuthResponse {
        guard let url = URL(string: "\(serverURL)/api/auth/login") else {
            throw PodcastServiceAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = AuthRequest(email: email, password: password)
        request.httpBody = try encoder.encode(body)
        
        let (data, response) = try await session.data(for: request)
        
        try validateResponse(response, data: data)
        
        return try decoder.decode(AuthResponse.self, from: data)
    }
    
    // MARK: - Subscriptions
    
    func getSubscriptions(
        serverURL: String,
        apiKey: String
    ) async throws -> PodcastsResponse {
        guard let url = URL(string: "\(serverURL)/api/podcasts") else {
            throw PodcastServiceAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await session.data(for: request)
        
        try validateResponse(response, data: data)
        
        return try decoder.decode(PodcastsResponse.self, from: data)
    }
    
    func subscribe(
        serverURL: String,
        apiKey: String,
        feedURL: String
    ) async throws -> SubscribeResponse {
        guard let url = URL(string: "\(serverURL)/api/podcasts/subscribe") else {
            throw PodcastServiceAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = SubscribeRequest(feedUrl: feedURL)
        request.httpBody = try encoder.encode(body)
        
        let (data, response) = try await session.data(for: request)
        
        try validateResponse(response, data: data)
        
        return try decoder.decode(SubscribeResponse.self, from: data)
    }
    
    func unsubscribe(
        serverURL: String,
        apiKey: String,
        podcastId: String
    ) async throws -> UnsubscribeResponse {
        guard let url = URL(string: "\(serverURL)/api/podcasts/\(podcastId)") else {
            throw PodcastServiceAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        
        try validateResponse(response, data: data)
        
        return try decoder.decode(UnsubscribeResponse.self, from: data)
    }
    
    func refreshPodcast(
        serverURL: String,
        apiKey: String,
        podcastId: String
    ) async throws {
        guard let url = URL(string: "\(serverURL)/api/podcasts/\(podcastId)/refresh") else {
            throw PodcastServiceAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        
        try validateResponse(response, data: data)
    }
    
    func searchPodcasts(
        serverURL: String,
        apiKey: String,
        query: String,
        limit: Int?
    ) async throws -> PodcastSearchResponse {
        var components = URLComponents(string: "\(serverURL)/api/podcasts/search")
        var queryItems = [URLQueryItem(name: "q", value: query)]
        if let limit = limit {
            queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        }
        components?.queryItems = queryItems
        
        guard let url = components?.url else {
            throw PodcastServiceAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await session.data(for: request)
        
        try validateResponse(response, data: data)
        
        return try decoder.decode(PodcastSearchResponse.self, from: data)
    }
    
    // MARK: - Episodes
    
    func getEpisodes(
        serverURL: String,
        apiKey: String,
        podcastId: String?,
        limit: Int?,
        offset: Int?,
        filter: String?,
        sort: String?
    ) async throws -> EpisodesResponse {
        var components = URLComponents(string: "\(serverURL)/api/episodes")
        var queryItems: [URLQueryItem] = []
        
        if let podcastId = podcastId {
            queryItems.append(URLQueryItem(name: "podcastId", value: podcastId))
        }
        if let limit = limit {
            queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        }
        if let offset = offset {
            queryItems.append(URLQueryItem(name: "offset", value: String(offset)))
        }
        if let filter = filter {
            queryItems.append(URLQueryItem(name: "filter", value: filter))
        }
        if let sort = sort {
            queryItems.append(URLQueryItem(name: "sort", value: sort))
        }
        
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }
        
        guard let url = components?.url else {
            throw PodcastServiceAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await session.data(for: request)
        
        try validateResponse(response, data: data)
        
        return try decoder.decode(EpisodesResponse.self, from: data)
    }
    
    // MARK: - Progress
    
    func getProgress(
        serverURL: String,
        apiKey: String
    ) async throws -> ProgressResponse {
        guard let url = URL(string: "\(serverURL)/api/progress") else {
            throw PodcastServiceAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await session.data(for: request)
        
        try validateResponse(response, data: data)
        
        return try decoder.decode(ProgressResponse.self, from: data)
    }
    
    func updateProgress(
        serverURL: String,
        apiKey: String,
        episodeId: String,
        positionSeconds: Int,
        durationSeconds: Int,
        completed: Bool
    ) async throws -> ProgressUpdateResponse {
        guard let url = URL(string: "\(serverURL)/api/progress/\(episodeId)") else {
            throw PodcastServiceAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ProgressUpdateRequest(
            positionSeconds: positionSeconds,
            durationSeconds: durationSeconds,
            completed: completed
        )
        request.httpBody = try encoder.encode(body)
        
        let (data, response) = try await session.data(for: request)
        
        try validateResponse(response, data: data)
        
        return try decoder.decode(ProgressUpdateResponse.self, from: data)
    }
    
    func bulkUpdateProgress(
        serverURL: String,
        apiKey: String,
        updates: [BulkProgressUpdate]
    ) async throws -> BulkProgressUpdateResponse {
        guard let url = URL(string: "\(serverURL)/api/progress") else {
            throw PodcastServiceAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = BulkProgressUpdateRequest(updates: updates)
        request.httpBody = try encoder.encode(body)
        
        let (data, response) = try await session.data(for: request)
        
        try validateResponse(response, data: data)
        
        return try decoder.decode(BulkProgressUpdateResponse.self, from: data)
    }

    // MARK: - Queue

    func getQueue(
        serverURL: String,
        apiKey: String
    ) async throws -> QueueResponse {
        guard let url = URL(string: "\(serverURL)/api/queue") else {
            throw PodcastServiceAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        try validateResponse(response, data: data)

        return try decoder.decode(QueueResponse.self, from: data)
    }

    func addToQueue(
        serverURL: String,
        apiKey: String,
        episodeId: String
    ) async throws -> AddToQueueResponse {
        guard let url = URL(string: "\(serverURL)/api/queue") else {
            throw PodcastServiceAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = AddToQueueRequest(episodeId: episodeId)
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await session.data(for: request)

        try validateResponse(response, data: data)

        return try decoder.decode(AddToQueueResponse.self, from: data)
    }

    func reorderQueue(
        serverURL: String,
        apiKey: String,
        items: [QueueReorderItem]
    ) async throws -> QueueResponse {
        guard let url = URL(string: "\(serverURL)/api/queue") else {
            throw PodcastServiceAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = QueueReorderRequest(items: items)
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await session.data(for: request)

        try validateResponse(response, data: data)

        return try decoder.decode(QueueResponse.self, from: data)
    }

    func clearQueue(
        serverURL: String,
        apiKey: String,
        currentEpisodeId: String?
    ) async throws -> QueueResponse {
        var components = URLComponents(string: "\(serverURL)/api/queue")
        if let currentEpisodeId = currentEpisodeId {
            components?.queryItems = [URLQueryItem(name: "currentEpisodeId", value: currentEpisodeId)]
        }

        guard let url = components?.url else {
            throw PodcastServiceAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        try validateResponse(response, data: data)

        return try decoder.decode(QueueResponse.self, from: data)
    }

    func removeFromQueue(
        serverURL: String,
        apiKey: String,
        queueItemId: String
    ) async throws -> UnsubscribeResponse {
        guard let url = URL(string: "\(serverURL)/api/queue/\(queueItemId)") else {
            throw PodcastServiceAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        try validateResponse(response, data: data)

        return try decoder.decode(UnsubscribeResponse.self, from: data)
    }

    // MARK: - Playlists

    func getPlaylists(
        serverURL: String,
        apiKey: String
    ) async throws -> PlaylistsResponse {
        guard let url = URL(string: "\(serverURL)/api/playlists") else {
            throw PodcastServiceAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        try validateResponse(response, data: data)

        return try decoder.decode(PlaylistsResponse.self, from: data)
    }

    func createPlaylist(
        serverURL: String,
        apiKey: String,
        name: String,
        description: String?
    ) async throws -> CreatePlaylistResponse {
        guard let url = URL(string: "\(serverURL)/api/playlists") else {
            throw PodcastServiceAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = CreatePlaylistRequest(name: name, description: description)
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await session.data(for: request)

        try validateResponse(response, data: data)

        return try decoder.decode(CreatePlaylistResponse.self, from: data)
    }

    func getPlaylist(
        serverURL: String,
        apiKey: String,
        playlistId: String
    ) async throws -> PlaylistDetailResponse {
        guard let url = URL(string: "\(serverURL)/api/playlists/\(playlistId)") else {
            throw PodcastServiceAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        try validateResponse(response, data: data)

        return try decoder.decode(PlaylistDetailResponse.self, from: data)
    }

    func updatePlaylist(
        serverURL: String,
        apiKey: String,
        playlistId: String,
        name: String?,
        description: String?
    ) async throws -> APIPlaylist {
        guard let url = URL(string: "\(serverURL)/api/playlists/\(playlistId)") else {
            throw PodcastServiceAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = UpdatePlaylistRequest(name: name, description: description)
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await session.data(for: request)

        try validateResponse(response, data: data)

        return try decoder.decode(APIPlaylist.self, from: data)
    }

    func deletePlaylist(
        serverURL: String,
        apiKey: String,
        playlistId: String
    ) async throws -> UnsubscribeResponse {
        guard let url = URL(string: "\(serverURL)/api/playlists/\(playlistId)") else {
            throw PodcastServiceAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        try validateResponse(response, data: data)

        return try decoder.decode(UnsubscribeResponse.self, from: data)
    }

    func addToPlaylist(
        serverURL: String,
        apiKey: String,
        playlistId: String,
        podcastId: String?,
        episodeId: String?,
        position: Int?
    ) async throws -> APIModelPlaylistItem {
        guard let url = URL(string: "\(serverURL)/api/playlists/\(playlistId)/items") else {
            throw PodcastServiceAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = AddToPlaylistRequest(podcastId: podcastId, episodeId: episodeId, position: position)
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await session.data(for: request)

        try validateResponse(response, data: data)

        return try decoder.decode(APIModelPlaylistItem.self, from: data)
    }

    func updatePlaylistItem(
        serverURL: String,
        apiKey: String,
        playlistId: String,
        itemId: String,
        position: Int
    ) async throws {
        guard let url = URL(string: "\(serverURL)/api/playlists/\(playlistId)/items/\(itemId)") else {
            throw PodcastServiceAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = UpdatePlaylistItemRequest(position: position)
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await session.data(for: request)

        try validateResponse(response, data: data)
    }

    func removeFromPlaylist(
        serverURL: String,
        apiKey: String,
        playlistId: String,
        itemId: String
    ) async throws -> UnsubscribeResponse {
        guard let url = URL(string: "\(serverURL)/api/playlists/\(playlistId)/items/\(itemId)") else {
            throw PodcastServiceAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        try validateResponse(response, data: data)

        return try decoder.decode(UnsubscribeResponse.self, from: data)
    }

    // MARK: - Private Helpers
    
    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PodcastServiceAPIError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200..<300:
            return
        case 400:
            let errorMessage = parseErrorMessage(from: data)
            throw PodcastServiceAPIError.validationError(details: errorMessage)
        case 401:
            throw PodcastServiceAPIError.unauthorized
        case 403:
            throw PodcastServiceAPIError.forbidden
        case 404:
            throw PodcastServiceAPIError.notFound
        case 409:
            let errorMessage = parseErrorMessage(from: data)
            throw PodcastServiceAPIError.conflict(message: errorMessage)
        default:
            let errorMessage = parseErrorMessage(from: data)
            throw PodcastServiceAPIError.serverError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
    }
    
    private func parseErrorMessage(from data: Data) -> String? {
        if let errorResponse = try? decoder.decode(APIErrorResponse.self, from: data) {
            return errorResponse.error
        }
        return String(data: data, encoding: .utf8)
    }
}
