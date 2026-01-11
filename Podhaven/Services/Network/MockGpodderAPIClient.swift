import Foundation

/// Mock implementation for testing and previews
final class MockGpodderAPIClient: GpodderAPIClientProtocol, @unchecked Sendable {
    // Test configuration
    var shouldFail = false
    var errorToThrow: GpodderAPIError = .unauthorized
    var loginDelay: UInt64 = 0
    
    // Mock data
    var mockSubscriptions: [String] = [
        "https://feeds.simplecast.com/54nAGcIl",
        "https://feeds.megaphone.fm/ATP"
    ]
    
    var mockEpisodeActions: [GpodderEpisodeAction] = []
    
    // Tracking calls for verification in tests
    var loginCallCount = 0
    var getSubscriptionsCallCount = 0
    var updateSubscriptionsCallCount = 0
    var getEpisodeActionsCallCount = 0
    var uploadEpisodeActionsCallCount = 0
    
    func login(
        serverURL: String,
        username: String,
        password: String
    ) async throws -> AuthResponse {
        loginCallCount += 1
        
        if loginDelay > 0 {
            try await Task.sleep(nanoseconds: loginDelay)
        }
        
        if shouldFail {
            throw errorToThrow
        }
        
        return AuthResponse(
            success: true,
            sessionCookie: "mock-session-cookie",
            message: "Login successful"
        )
    }
    
    func getSubscriptions(
        serverURL: String,
        username: String,
        sessionCookie: String
    ) async throws -> [String] {
        getSubscriptionsCallCount += 1
        
        if shouldFail {
            throw errorToThrow
        }
        
        return mockSubscriptions
    }
    
    func updateSubscriptions(
        serverURL: String,
        username: String,
        sessionCookie: String,
        add: [String],
        remove: [String]
    ) async throws -> SubscriptionUpdateResponse {
        updateSubscriptionsCallCount += 1
        
        if shouldFail {
            throw errorToThrow
        }
        
        // Update mock data
        mockSubscriptions.append(contentsOf: add)
        mockSubscriptions.removeAll { remove.contains($0) }
        
        return SubscriptionUpdateResponse(
            timestamp: Int64(Date().timeIntervalSince1970),
            updateURLs: nil
        )
    }
    
    func getEpisodeActions(
        serverURL: String,
        username: String,
        sessionCookie: String,
        since: Int64?
    ) async throws -> EpisodeActionsResponse {
        getEpisodeActionsCallCount += 1
        
        if shouldFail {
            throw errorToThrow
        }
        
        return EpisodeActionsResponse(
            actions: mockEpisodeActions,
            timestamp: Int64(Date().timeIntervalSince1970)
        )
    }
    
    func uploadEpisodeActions(
        serverURL: String,
        username: String,
        sessionCookie: String,
        actions: [GpodderEpisodeAction]
    ) async throws -> EpisodeActionsUploadResponse {
        uploadEpisodeActionsCallCount += 1
        
        if shouldFail {
            throw errorToThrow
        }
        
        // Store uploaded actions
        mockEpisodeActions.append(contentsOf: actions)
        
        return EpisodeActionsUploadResponse(
            timestamp: Int64(Date().timeIntervalSince1970),
            updateURLs: nil
        )
    }
    
    // MARK: - Test Helpers
    
    func reset() {
        shouldFail = false
        loginCallCount = 0
        getSubscriptionsCallCount = 0
        updateSubscriptionsCallCount = 0
        getEpisodeActionsCallCount = 0
        uploadEpisodeActionsCallCount = 0
        mockEpisodeActions = []
    }
}
