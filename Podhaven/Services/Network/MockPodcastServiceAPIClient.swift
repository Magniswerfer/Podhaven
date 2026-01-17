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
        mockSubscriptions = []
        mockProgress = []
        mockEpisodes = []
        mockSearchResults = []
    }
}
