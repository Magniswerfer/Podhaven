import Foundation

/// Mock implementation for testing and previews
final class MockPodcastServiceAPIClient: PodcastServiceAPIClientProtocol, @unchecked Sendable {
    // Test configuration
    var shouldFail = false
    var errorToThrow: PodcastServiceAPIError = .unauthorized
    var loginDelay: UInt64 = 0
    
    // Mock data
    var mockSubscriptions: [SubscribedPodcast] = []
    var mockProgress: [ProgressRecord] = []
    var mockEpisodes: [APIEpisode] = []
    var mockSearchResults: [PodcastSearchResult] = []
    
    // Mock data
    var mockQueue: [QueueItem] = []
    var mockPlaylists: [APIPlaylist] = []
    var mockPlaylistItems: [String: [PlaylistItem]] = [:] // playlistId -> items

    // Tracking calls for verification in tests
    var registerCallCount = 0
    var loginCallCount = 0
    var getSubscriptionsCallCount = 0
    var subscribeCallCount = 0
    var unsubscribeCallCount = 0
    var refreshPodcastCallCount = 0
    var searchPodcastsCallCount = 0
    var getEpisodesCallCount = 0
    var getProgressCallCount = 0
    var updateProgressCallCount = 0
    var bulkUpdateProgressCallCount = 0
    var getQueueCallCount = 0
    var addToQueueCallCount = 0
    var reorderQueueCallCount = 0
    var clearQueueCallCount = 0
    var removeFromQueueCallCount = 0
    var getPlaylistsCallCount = 0
    var createPlaylistCallCount = 0
    var getPlaylistCallCount = 0
    var updatePlaylistCallCount = 0
    var deletePlaylistCallCount = 0
    var addToPlaylistCallCount = 0
    var updatePlaylistItemCallCount = 0
    var removeFromPlaylistCallCount = 0
    
    // MARK: - Authentication
    
    func register(
        serverURL: String,
        email: String,
        password: String?
    ) async throws -> AuthResponse {
        registerCallCount += 1
        
        if loginDelay > 0 {
            try await Task.sleep(nanoseconds: loginDelay)
        }
        
        if shouldFail {
            throw errorToThrow
        }
        
        return AuthResponse(
            user: AuthUser(
                id: UUID().uuidString,
                email: email,
                apiKey: "mock-api-key-\(UUID().uuidString.prefix(8))"
            )
        )
    }
    
    func login(
        serverURL: String,
        email: String,
        password: String?
    ) async throws -> AuthResponse {
        loginCallCount += 1
        
        if loginDelay > 0 {
            try await Task.sleep(nanoseconds: loginDelay)
        }
        
        if shouldFail {
            throw errorToThrow
        }
        
        return AuthResponse(
            user: AuthUser(
                id: UUID().uuidString,
                email: email,
                apiKey: "mock-api-key-\(UUID().uuidString.prefix(8))"
            )
        )
    }
    
    // MARK: - Subscriptions
    
    func getSubscriptions(
        serverURL: String,
        apiKey: String
    ) async throws -> PodcastsResponse {
        getSubscriptionsCallCount += 1
        
        if shouldFail {
            throw errorToThrow
        }
        
        return PodcastsResponse(podcasts: mockSubscriptions)
    }
    
    func subscribe(
        serverURL: String,
        apiKey: String,
        feedURL: String
    ) async throws -> SubscribeResponse {
        subscribeCallCount += 1
        
        if shouldFail {
            throw errorToThrow
        }
        
        let podcastId = UUID().uuidString
        let newPodcast = SubscribedPodcast(
            id: podcastId,
            title: "Mock Podcast",
            description: "A mock podcast for testing",
            feedUrl: feedURL,
            artworkUrl: nil,
            author: "Mock Author",
            subscribedAt: Date(),
            episodeCount: 10,
            customSettings: nil
        )
        mockSubscriptions.append(newPodcast)
        
        return SubscribeResponse(
            podcast: SubscribedPodcastBasic(
                id: podcastId,
                title: "Mock Podcast",
                subscribedAt: Date(),
                episodeCount: 10
            )
        )
    }
    
    func unsubscribe(
        serverURL: String,
        apiKey: String,
        podcastId: String
    ) async throws -> UnsubscribeResponse {
        unsubscribeCallCount += 1
        
        if shouldFail {
            throw errorToThrow
        }
        
        mockSubscriptions.removeAll { $0.id == podcastId }
        
        return UnsubscribeResponse(success: true)
    }
    
    func refreshPodcast(
        serverURL: String,
        apiKey: String,
        podcastId: String
    ) async throws {
        refreshPodcastCallCount += 1
        
        if shouldFail {
            throw errorToThrow
        }
    }
    
    func searchPodcasts(
        serverURL: String,
        apiKey: String,
        query: String,
        limit: Int?
    ) async throws -> PodcastSearchResponse {
        searchPodcastsCallCount += 1
        
        if shouldFail {
            throw errorToThrow
        }
        
        let results = mockSearchResults.isEmpty ? [
            PodcastSearchResult(
                title: "Search Result for: \(query)",
                feedUrl: "https://example.com/\(query.lowercased().replacingOccurrences(of: " ", with: "-")).xml",
                artworkUrl: nil,
                author: "Mock Author"
            )
        ] : mockSearchResults
        
        return PodcastSearchResponse(results: results, count: results.count)
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
        getEpisodesCallCount += 1
        
        if shouldFail {
            throw errorToThrow
        }
        
        return EpisodesResponse(
            episodes: mockEpisodes,
            total: mockEpisodes.count,
            limit: limit ?? 20,
            offset: offset ?? 0
        )
    }
    
    // MARK: - Progress
    
    func getProgress(
        serverURL: String,
        apiKey: String
    ) async throws -> ProgressResponse {
        getProgressCallCount += 1
        
        if shouldFail {
            throw errorToThrow
        }
        
        return ProgressResponse(progress: mockProgress)
    }
    
    func updateProgress(
        serverURL: String,
        apiKey: String,
        episodeId: String,
        positionSeconds: Int,
        durationSeconds: Int,
        completed: Bool
    ) async throws -> ProgressUpdateResponse {
        updateProgressCallCount += 1
        
        if shouldFail {
            throw errorToThrow
        }
        
        let record = ProgressRecord(
            id: UUID().uuidString,
            episodeId: episodeId,
            positionSeconds: positionSeconds,
            durationSeconds: durationSeconds,
            completed: completed,
            lastUpdatedAt: Date(),
            episode: nil
        )
        
        // Update or add to mock progress
        if let index = mockProgress.firstIndex(where: { $0.episodeId == episodeId }) {
            mockProgress[index] = record
        } else {
            mockProgress.append(record)
        }
        
        return ProgressUpdateResponse(progress: record)
    }
    
    func bulkUpdateProgress(
        serverURL: String,
        apiKey: String,
        updates: [BulkProgressUpdate]
    ) async throws -> BulkProgressUpdateResponse {
        bulkUpdateProgressCallCount += 1
        
        if shouldFail {
            throw errorToThrow
        }
        
        let results = updates.map { update in
            let record = ProgressRecord(
                id: UUID().uuidString,
                episodeId: update.episodeId,
                positionSeconds: update.positionSeconds,
                durationSeconds: update.durationSeconds,
                completed: update.completed,
                lastUpdatedAt: Date(),
                episode: nil
            )
            return BulkProgressResult(
                episodeId: update.episodeId,
                success: true,
                progress: record,
                error: nil
            )
        }
        
        return BulkProgressUpdateResponse(results: results)
    }

    // MARK: - Queue

    func getQueue(
        serverURL: String,
        apiKey: String
    ) async throws -> QueueResponse {
        getQueueCallCount += 1

        if shouldFail {
            throw errorToThrow
        }

        return QueueResponse(queue: mockQueue)
    }

    func addToQueue(
        serverURL: String,
        apiKey: String,
        episodeId: String
    ) async throws -> AddToQueueResponse {
        addToQueueCallCount += 1

        if shouldFail {
            throw errorToThrow
        }

        let queueItem = QueueItem(
            id: UUID().uuidString,
            episodeId: episodeId,
            position: mockQueue.count,
            episode: nil
        )

        mockQueue.append(queueItem)

        return AddToQueueResponse(queueItem: queueItem, queue: mockQueue)
    }

    func reorderQueue(
        serverURL: String,
        apiKey: String,
        items: [QueueReorderItem]
    ) async throws -> QueueResponse {
        reorderQueueCallCount += 1

        if shouldFail {
            throw errorToThrow
        }

        // Update positions based on reorder request
        for item in items {
            if let index = mockQueue.firstIndex(where: { $0.id == item.id }) {
                mockQueue[index] = QueueItem(
                    id: item.id,
                    episodeId: mockQueue[index].episodeId,
                    position: item.position,
                    episode: mockQueue[index].episode
                )
            }
        }

        // Sort by position
        mockQueue.sort { $0.position < $1.position }

        return QueueResponse(queue: mockQueue)
    }

    func clearQueue(
        serverURL: String,
        apiKey: String,
        currentEpisodeId: String?
    ) async throws -> QueueResponse {
        clearQueueCallCount += 1

        if shouldFail {
            throw errorToThrow
        }

        if let currentEpisodeId = currentEpisodeId {
            mockQueue = mockQueue.filter { $0.episodeId == currentEpisodeId }
        } else {
            mockQueue.removeAll()
        }

        return QueueResponse(queue: mockQueue)
    }

    func removeFromQueue(
        serverURL: String,
        apiKey: String,
        queueItemId: String
    ) async throws -> UnsubscribeResponse {
        removeFromQueueCallCount += 1

        if shouldFail {
            throw errorToThrow
        }

        mockQueue.removeAll { $0.id == queueItemId }

        return UnsubscribeResponse(success: true)
    }

    // MARK: - Playlists

    func getPlaylists(
        serverURL: String,
        apiKey: String
    ) async throws -> PlaylistsResponse {
        getPlaylistsCallCount += 1

        if shouldFail {
            throw errorToThrow
        }

        return PlaylistsResponse(playlists: mockPlaylists)
    }

    func createPlaylist(
        serverURL: String,
        apiKey: String,
        name: String,
        description: String?
    ) async throws -> CreatePlaylistResponse {
        createPlaylistCallCount += 1

        if shouldFail {
            throw errorToThrow
        }

        let playlist = APIPlaylist(
            id: UUID().uuidString,
            name: name,
            description: description,
            createdAt: Date(),
            updatedAt: Date(),
            _count: PlaylistCount(items: 0)
        )

        mockPlaylists.append(playlist)

        return CreatePlaylistResponse(playlist: playlist)
    }

    func getPlaylist(
        serverURL: String,
        apiKey: String,
        playlistId: String
    ) async throws -> PlaylistDetailResponse {
        getPlaylistCallCount += 1

        if shouldFail {
            throw errorToThrow
        }

        guard let playlist = mockPlaylists.first(where: { $0.id == playlistId }) else {
            throw PodcastServiceAPIError.notFound
        }

        let items = mockPlaylistItems[playlistId] ?? []

        let playlistWithItems = APIPlaylistWithItems(
            id: playlist.id,
            name: playlist.name,
            description: playlist.description,
            createdAt: playlist.createdAt,
            updatedAt: playlist.updatedAt,
            items: items
        )

        return PlaylistDetailResponse(playlist: playlistWithItems)
    }

    func updatePlaylist(
        serverURL: String,
        apiKey: String,
        playlistId: String,
        name: String?,
        description: String?
    ) async throws -> APIPlaylist {
        updatePlaylistCallCount += 1

        if shouldFail {
            throw errorToThrow
        }

        guard let index = mockPlaylists.firstIndex(where: { $0.id == playlistId }) else {
            throw PodcastServiceAPIError.notFound
        }

        var updatedPlaylist = mockPlaylists[index]
        if let name = name {
            updatedPlaylist = APIPlaylist(
                id: updatedPlaylist.id,
                name: name,
                description: updatedPlaylist.description,
                createdAt: updatedPlaylist.createdAt,
                updatedAt: Date(),
                _count: updatedPlaylist._count
            )
        }
        if let description = description {
            updatedPlaylist = APIPlaylist(
                id: updatedPlaylist.id,
                name: updatedPlaylist.name,
                description: description,
                createdAt: updatedPlaylist.createdAt,
                updatedAt: Date(),
                _count: updatedPlaylist._count
            )
        }

        mockPlaylists[index] = updatedPlaylist

        return updatedPlaylist
    }

    func deletePlaylist(
        serverURL: String,
        apiKey: String,
        playlistId: String
    ) async throws -> UnsubscribeResponse {
        deletePlaylistCallCount += 1

        if shouldFail {
            throw errorToThrow
        }

        mockPlaylists.removeAll { $0.id == playlistId }
        mockPlaylistItems.removeValue(forKey: playlistId)

        return UnsubscribeResponse(success: true)
    }

    func addToPlaylist(
        serverURL: String,
        apiKey: String,
        playlistId: String,
        podcastId: String?,
        episodeId: String?,
        position: Int?
    ) async throws -> PlaylistItem {
        addToPlaylistCallCount += 1

        if shouldFail {
            throw errorToThrow
        }

        let item = PlaylistItem(
            id: UUID().uuidString,
            position: position ?? (mockPlaylistItems[playlistId]?.count ?? 0),
            podcast: nil,
            episode: nil
        )

        if mockPlaylistItems[playlistId] == nil {
            mockPlaylistItems[playlistId] = []
        }
        mockPlaylistItems[playlistId]?.append(item)

        return item
    }

    func updatePlaylistItem(
        serverURL: String,
        apiKey: String,
        playlistId: String,
        itemId: String,
        position: Int
    ) async throws {
        updatePlaylistItemCallCount += 1

        if shouldFail {
            throw errorToThrow
        }

        guard var items = mockPlaylistItems[playlistId],
              let index = items.firstIndex(where: { $0.id == itemId }) else {
            throw PodcastServiceAPIError.notFound
        }

        items[index] = PlaylistItem(
            id: itemId,
            position: position,
            podcast: items[index].podcast,
            episode: items[index].episode
        )

        mockPlaylistItems[playlistId] = items
    }

    func removeFromPlaylist(
        serverURL: String,
        apiKey: String,
        playlistId: String,
        itemId: String
    ) async throws -> UnsubscribeResponse {
        removeFromPlaylistCallCount += 1

        if shouldFail {
            throw errorToThrow
        }

        mockPlaylistItems[playlistId]?.removeAll { $0.id == itemId }

        return UnsubscribeResponse(success: true)
    }

    // MARK: - Test Helpers
    
    func reset() {
        shouldFail = false
        registerCallCount = 0
        loginCallCount = 0
        getSubscriptionsCallCount = 0
        subscribeCallCount = 0
        unsubscribeCallCount = 0
        refreshPodcastCallCount = 0
        searchPodcastsCallCount = 0
        getEpisodesCallCount = 0
        getProgressCallCount = 0
        updateProgressCallCount = 0
        bulkUpdateProgressCallCount = 0
        getQueueCallCount = 0
        addToQueueCallCount = 0
        reorderQueueCallCount = 0
        clearQueueCallCount = 0
        removeFromQueueCallCount = 0
        getPlaylistsCallCount = 0
        createPlaylistCallCount = 0
        getPlaylistCallCount = 0
        updatePlaylistCallCount = 0
        deletePlaylistCallCount = 0
        addToPlaylistCallCount = 0
        updatePlaylistItemCallCount = 0
        removeFromPlaylistCallCount = 0
        mockSubscriptions = []
        mockProgress = []
        mockEpisodes = []
        mockSearchResults = []
        mockQueue = []
        mockPlaylists = []
        mockPlaylistItems = [:]
    }
}
