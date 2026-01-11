import Foundation
import SwiftData
import Observation

/// Service for syncing with gpodder server
@Observable
@MainActor
final class SyncService {
    // MARK: - State
    
    private(set) var isSyncing = false
    private(set) var lastError: Error?
    private(set) var syncProgress: String = ""
    
    // MARK: - Dependencies
    
    private let apiClient: GpodderAPIClientProtocol
    private let modelContext: ModelContext
    private let rssParser: RSSParserProtocol
    
    // MARK: - Initialization
    
    init(
        apiClient: GpodderAPIClientProtocol,
        modelContext: ModelContext,
        rssParser: RSSParserProtocol = RSSParser()
    ) {
        self.apiClient = apiClient
        self.modelContext = modelContext
        self.rssParser = rssParser
    }
    
    // MARK: - Public Methods
    
    /// Perform a full sync with the server
    func performSync() async throws {
        guard !isSyncing else { return }
        
        isSyncing = true
        lastError = nil
        
        defer { isSyncing = false }
        
        let config = try getServerConfiguration()
        guard config.isAuthenticated, let session = config.sessionCookie else {
            throw GpodderAPIError.noSession
        }
        
        let syncState = try getSyncState()
        syncState.markSyncStarted()
        
        do {
            // Sync subscriptions
            syncProgress = "Syncing subscriptions..."
            try await syncSubscriptions(config: config, session: session, syncState: syncState)
            
            // Sync episode actions
            syncProgress = "Syncing episode progress..."
            try await syncEpisodeActions(config: config, session: session, syncState: syncState)
            
            syncState.markSyncCompleted()
            syncProgress = "Sync complete"
            
            try modelContext.save()
        } catch {
            syncState.markSyncFailed(error: error.localizedDescription)
            lastError = error
            try? modelContext.save()
            throw error
        }
    }
    
    /// Login to gpodder server
    func login(serverURL: String, username: String, password: String) async throws {
        let response = try await apiClient.login(
            serverURL: serverURL,
            username: username,
            password: password
        )
        
        guard response.success else {
            throw GpodderAPIError.unauthorized
        }
        
        // Save configuration
        let config = try getServerConfiguration()
        config.serverURL = serverURL
        config.username = username
        config.sessionCookie = response.sessionCookie
        config.isAuthenticated = true
        config.lastAuthenticatedAt = .now
        
        try modelContext.save()
    }
    
    /// Logout and clear session
    func logout() throws {
        let config = try getServerConfiguration()
        config.isAuthenticated = false
        config.sessionCookie = nil
        
        try modelContext.save()
    }
    
    /// Subscribe to a podcast
    func subscribe(to feedURL: String) async throws -> Podcast {
        // Check if already subscribed
        let descriptor = FetchDescriptor<Podcast>(
            predicate: #Predicate { $0.feedURL == feedURL }
        )
        
        if let existing = try modelContext.fetch(descriptor).first {
            existing.isSubscribed = true
            existing.needsSync = true
            return existing
        }
        
        // Parse the feed
        guard let url = URL(string: feedURL) else {
            throw RSSParserError.invalidFeed
        }
        
        let parsed = try await rssParser.parseFeed(from: url)
        
        // Create podcast
        let podcast = Podcast(
            feedURL: feedURL,
            title: parsed.title,
            author: parsed.author,
            podcastDescription: parsed.description,
            artworkURL: parsed.artworkURL,
            link: parsed.link,
            language: parsed.language,
            categories: parsed.categories
        )
        
        modelContext.insert(podcast)
        
        // Create episodes
        for parsedEpisode in parsed.episodes {
            let episode = Episode(
                guid: parsedEpisode.guid,
                podcastFeedURL: feedURL,
                title: parsedEpisode.title,
                audioURL: parsedEpisode.audioURL,
                episodeDescription: parsedEpisode.description,
                publishDate: parsedEpisode.publishDate,
                duration: parsedEpisode.duration,
                fileSize: parsedEpisode.fileSize,
                episodeNumber: parsedEpisode.episodeNumber,
                seasonNumber: parsedEpisode.seasonNumber,
                artworkURL: parsedEpisode.artworkURL
            )
            episode.podcast = podcast
            modelContext.insert(episode)
        }
        
        podcast.lastUpdated = .now
        
        try modelContext.save()
        
        // Queue sync
        await queueSubscriptionChange(add: [feedURL])
        
        return podcast
    }
    
    /// Unsubscribe from a podcast
    func unsubscribe(from podcast: Podcast) async throws {
        podcast.isSubscribed = false
        podcast.needsSync = true
        
        try modelContext.save()
        
        await queueSubscriptionChange(remove: [podcast.feedURL])
    }
    
    /// Record an episode action (play progress)
    func recordEpisodeAction(
        episode: Episode,
        action: ActionType,
        position: TimeInterval? = nil,
        total: TimeInterval? = nil
    ) async throws {
        guard let podcast = episode.podcast else { return }
        
        let episodeAction = EpisodeAction(
            podcastURL: podcast.feedURL,
            episodeURL: episode.audioURL,
            action: action,
            position: position,
            total: total ?? episode.duration
        )
        
        modelContext.insert(episodeAction)
        
        // Update episode state
        if let position = position {
            episode.playbackPosition = position
        }
        episode.lastPlayedAt = .now
        episode.needsSync = true
        
        try modelContext.save()
    }
    
    /// Refresh a podcast's feed
    func refreshPodcast(_ podcast: Podcast) async throws {
        guard let url = URL(string: podcast.feedURL) else {
            throw RSSParserError.invalidFeed
        }
        
        let parsed = try await rssParser.parseFeed(from: url)
        
        // Update podcast metadata
        podcast.title = parsed.title
        podcast.author = parsed.author
        podcast.podcastDescription = parsed.description
        podcast.artworkURL = parsed.artworkURL
        
        // Add new episodes
        let existingGUIDs = Set(podcast.episodes.map { $0.guid })
        
        for parsedEpisode in parsed.episodes {
            guard !existingGUIDs.contains(parsedEpisode.guid) else { continue }
            
            let episode = Episode(
                guid: parsedEpisode.guid,
                podcastFeedURL: podcast.feedURL,
                title: parsedEpisode.title,
                audioURL: parsedEpisode.audioURL,
                episodeDescription: parsedEpisode.description,
                publishDate: parsedEpisode.publishDate,
                duration: parsedEpisode.duration,
                fileSize: parsedEpisode.fileSize,
                episodeNumber: parsedEpisode.episodeNumber,
                seasonNumber: parsedEpisode.seasonNumber,
                artworkURL: parsedEpisode.artworkURL
            )
            episode.podcast = podcast
            modelContext.insert(episode)
        }
        
        podcast.lastUpdated = .now
        
        try modelContext.save()
    }
    
    // MARK: - Private Methods
    
    private func getServerConfiguration() throws -> ServerConfiguration {
        let descriptor = FetchDescriptor<ServerConfiguration>()
        if let config = try modelContext.fetch(descriptor).first {
            return config
        }
        
        let config = ServerConfiguration()
        modelContext.insert(config)
        return config
    }
    
    private func getSyncState() throws -> SyncState {
        let descriptor = FetchDescriptor<SyncState>()
        if let state = try modelContext.fetch(descriptor).first {
            return state
        }
        
        let state = SyncState()
        modelContext.insert(state)
        return state
    }
    
    private func syncSubscriptions(
        config: ServerConfiguration,
        session: String,
        syncState: SyncState
    ) async throws {
        // Get server subscriptions
        let serverSubs = try await apiClient.getSubscriptions(
            serverURL: config.serverURL,
            username: config.username,
            sessionCookie: session
        )
        
        // Get local subscriptions
        let localDescriptor = FetchDescriptor<Podcast>(
            predicate: #Predicate { $0.isSubscribed }
        )
        let localPodcasts = try modelContext.fetch(localDescriptor)
        let localSubs = Set(localPodcasts.map { $0.feedURL })
        let serverSubsSet = Set(serverSubs)
        
        // Find new subscriptions from server
        let newFromServer = serverSubsSet.subtracting(localSubs)
        for feedURL in newFromServer {
            // Subscribe to new podcasts from server
            _ = try? await subscribe(to: feedURL)
        }
        
        // Upload local subscriptions not on server
        let localOnly = localSubs.subtracting(serverSubsSet)
        if !localOnly.isEmpty {
            _ = try await apiClient.updateSubscriptions(
                serverURL: config.serverURL,
                username: config.username,
                sessionCookie: session,
                add: Array(localOnly),
                remove: []
            )
        }
        
        // Handle unsubscriptions
        let pendingUnsubscribe = localPodcasts.filter { !$0.isSubscribed && $0.needsSync }
        if !pendingUnsubscribe.isEmpty {
            let urls = pendingUnsubscribe.map { $0.feedURL }
            _ = try await apiClient.updateSubscriptions(
                serverURL: config.serverURL,
                username: config.username,
                sessionCookie: session,
                add: [],
                remove: urls
            )
            
            for podcast in pendingUnsubscribe {
                podcast.needsSync = false
            }
        }
        
        syncState.lastSubscriptionSync = .now
    }
    
    private func syncEpisodeActions(
        config: ServerConfiguration,
        session: String,
        syncState: SyncState
    ) async throws {
        // Get episode actions from server
        let response = try await apiClient.getEpisodeActions(
            serverURL: config.serverURL,
            username: config.username,
            sessionCookie: session,
            since: syncState.episodeActionTimestamp
        )
        
        // Apply server actions to local episodes
        for action in response.actions {
            try await applyEpisodeAction(action)
        }
        
        // Upload local pending actions
        let pendingDescriptor = FetchDescriptor<EpisodeAction>(
            predicate: #Predicate { !$0.isSynced }
        )
        let pendingActions = try modelContext.fetch(pendingDescriptor)
        
        if !pendingActions.isEmpty {
            let gpodderActions = pendingActions.map { action in
                GpodderEpisodeAction(
                    podcast: action.podcastURL,
                    episode: action.episodeURL,
                    action: action.action.rawValue,
                    timestamp: action.timestamp,
                    position: action.position.map { Int($0) },
                    started: action.started.map { Int($0) },
                    total: action.total.map { Int($0) }
                )
            }
            
            _ = try await apiClient.uploadEpisodeActions(
                serverURL: config.serverURL,
                username: config.username,
                sessionCookie: session,
                actions: gpodderActions
            )
            
            // Mark as synced
            for action in pendingActions {
                action.isSynced = true
            }
        }
        
        syncState.episodeActionTimestamp = response.timestamp
        syncState.lastEpisodeActionSync = .now
    }
    
    private func applyEpisodeAction(_ action: GpodderEpisodeAction) async throws {
        // Find the episode
        let episodeURL = action.episode
        let descriptor = FetchDescriptor<Episode>(
            predicate: #Predicate { $0.audioURL == episodeURL }
        )
        
        guard let episode = try modelContext.fetch(descriptor).first else {
            return // Episode not found locally
        }
        
        // Apply the action
        switch action.action {
        case "play":
            if let position = action.position {
                // Only update if server position is newer
                let serverTime = action.timestamp ?? .now
                if episode.lastSyncedAt == nil || serverTime > episode.lastSyncedAt! {
                    episode.playbackPosition = TimeInterval(position)
                }
            }
        default:
            break
        }
        
        episode.lastSyncedAt = action.timestamp ?? .now
    }
    
    private func queueSubscriptionChange(add: [String] = [], remove: [String] = []) async {
        // This would trigger a background sync in a real implementation
        // For now, it marks podcasts as needing sync
    }
}

// MARK: - Preview

extension SyncService {
    static var preview: SyncService {
        let schema = Schema([
            Podcast.self,
            Episode.self,
            EpisodeAction.self,
            SyncState.self,
            ServerConfiguration.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        
        return SyncService(
            apiClient: MockGpodderAPIClient(),
            modelContext: container.mainContext
        )
    }
}
