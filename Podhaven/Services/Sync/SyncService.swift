import Foundation
import SwiftData
import Observation

/// Service for syncing with the podcast sync server
@Observable
@MainActor
final class SyncService {
    // MARK: - State
    
    private(set) var isSyncing = false
    private(set) var lastError: Error?
    private(set) var syncProgress: String = ""
    
    // MARK: - Dependencies
    
    private let apiClient: PodcastServiceAPIClientProtocol
    private let modelContext: ModelContext
    private let rssParser: RSSParserProtocol
    
    // MARK: - Initialization
    
    init(
        apiClient: PodcastServiceAPIClientProtocol,
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
        guard config.isAuthenticated, let apiKey = config.apiKey else {
            throw PodcastServiceAPIError.noAPIKey
        }

        let syncState = try getSyncState()
        syncState.markSyncStarted()

        do {
            // Sync subscriptions
            syncProgress = "Syncing subscriptions..."
            print("SyncService: Starting subscription sync")
            try await syncSubscriptions(config: config, apiKey: apiKey, syncState: syncState)
            print("SyncService: Subscription sync completed")

            // Sync progress
            syncProgress = "Syncing listening progress..."
            print("SyncService: Starting progress sync")
            try await syncProgress(config: config, apiKey: apiKey, syncState: syncState)
            print("SyncService: Progress sync completed")

            syncState.markSyncCompleted()
            syncProgress = "Sync complete"
            print("SyncService: Sync completed successfully")

            try modelContext.save()
        } catch {
            print("SyncService: Sync failed with error: \(error)")
            syncState.markSyncFailed(error: error.localizedDescription)
            lastError = error
            try? modelContext.save()
            throw error
        }
    }
    
    /// Register a new account
    func register(serverURL: String, email: String, password: String) async throws {
        let response = try await apiClient.register(
            serverURL: serverURL,
            email: email,
            password: password
        )
        
        // Save configuration
        let config = try getServerConfiguration()
        config.serverURL = serverURL
        config.email = email
        config.apiKey = response.user.apiKey
        config.isAuthenticated = true
        config.lastAuthenticatedAt = .now
        
        try modelContext.save()
    }
    
    /// Login to the server
    func login(serverURL: String, email: String, password: String) async throws {
        let response = try await apiClient.login(
            serverURL: serverURL,
            email: email,
            password: password
        )
        
        // Save configuration
        let config = try getServerConfiguration()
        config.serverURL = serverURL
        config.email = email
        config.apiKey = response.user.apiKey
        config.isAuthenticated = true
        config.lastAuthenticatedAt = .now
        
        try modelContext.save()
    }
    
    /// Logout and clear session
    func logout() throws {
        let config = try getServerConfiguration()
        config.isAuthenticated = false
        config.apiKey = nil
        
        try modelContext.save()
    }
    
    /// Subscribe to a podcast
    func subscribe(to feedURL: String) async throws -> Podcast {
        // Check if already subscribed locally
        let descriptor = FetchDescriptor<Podcast>(
            predicate: #Predicate { $0.feedURL == feedURL }
        )
        
        if let existing = try modelContext.fetch(descriptor).first {
            existing.isSubscribed = true
            existing.needsSync = true
            return existing
        }
        
        // Parse the feed first to get metadata
        guard let url = URL(string: feedURL) else {
            throw RSSParserError.invalidFeed
        }
        
        let parsed = try await rssParser.parseFeed(from: url)
        
        // Create local podcast
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
                showNotesHTML: parsedEpisode.showNotesHTML,
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
        
        // Subscribe on server if authenticated
        let config = try getServerConfiguration()
        if config.isAuthenticated, let apiKey = config.apiKey {
            do {
                let response = try await apiClient.subscribe(
                    serverURL: config.serverURL,
                    apiKey: apiKey,
                    feedURL: feedURL
                )
                podcast.serverPodcastId = response.podcast.id
                podcast.needsSync = false
            } catch {
                print("SyncService: Failed to subscribe on server: \(error)")
                // Keep needsSync = true so it will be synced later
            }
        }
        
        try modelContext.save()
        
        return podcast
    }
    
    /// Unsubscribe from a podcast
    func unsubscribe(from podcast: Podcast) async throws {
        podcast.isSubscribed = false
        
        // Unsubscribe on server if authenticated and we have a server ID
        let config = try getServerConfiguration()
        if config.isAuthenticated, 
           let apiKey = config.apiKey,
           let serverPodcastId = podcast.serverPodcastId {
            do {
                _ = try await apiClient.unsubscribe(
                    serverURL: config.serverURL,
                    apiKey: apiKey,
                    podcastId: serverPodcastId
                )
                podcast.needsSync = false
            } catch {
                print("SyncService: Failed to unsubscribe on server: \(error)")
                podcast.needsSync = true
            }
        }
        
        try modelContext.save()
    }
    
    /// Record episode progress
    func recordProgress(
        episode: Episode,
        position: TimeInterval,
        completed: Bool = false
    ) async throws {
        // Update local state
        episode.playbackPosition = position
        episode.lastPlayedAt = .now
        episode.needsSync = true
        
        if completed {
            episode.isPlayed = true
        }
        
        // Try to sync immediately if authenticated
        let config = try getServerConfiguration()
        if config.isAuthenticated,
           let apiKey = config.apiKey,
           let serverEpisodeId = episode.serverEpisodeId {
            do {
                _ = try await apiClient.updateProgress(
                    serverURL: config.serverURL,
                    apiKey: apiKey,
                    episodeId: serverEpisodeId,
                    positionSeconds: Int(position),
                    durationSeconds: Int(episode.duration ?? 0),
                    completed: completed
                )
                episode.needsSync = false
                episode.lastSyncedAt = .now
            } catch {
                print("SyncService: Failed to update progress on server: \(error)")
                // Queue for later sync
                let action = EpisodeAction(
                    episodeId: episode.id,
                    serverEpisodeId: serverEpisodeId,
                    positionSeconds: Int(position),
                    durationSeconds: Int(episode.duration ?? 0),
                    completed: completed
                )
                modelContext.insert(action)
            }
        } else if let serverEpisodeId = episode.serverEpisodeId {
            // Queue for later sync
            let action = EpisodeAction(
                episodeId: episode.id,
                serverEpisodeId: serverEpisodeId,
                positionSeconds: Int(position),
                durationSeconds: Int(episode.duration ?? 0),
                completed: completed
            )
            modelContext.insert(action)
        }
        
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
                showNotesHTML: parsedEpisode.showNotesHTML,
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
        
        // Trigger server-side refresh if authenticated
        let config = try getServerConfiguration()
        if config.isAuthenticated,
           let apiKey = config.apiKey,
           let serverPodcastId = podcast.serverPodcastId {
            do {
                try await apiClient.refreshPodcast(
                    serverURL: config.serverURL,
                    apiKey: apiKey,
                    podcastId: serverPodcastId
                )
            } catch {
                print("SyncService: Server refresh failed: \(error)")
                // Continue anyway - local refresh succeeded
            }
        }
        
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
        apiKey: String,
        syncState: SyncState
    ) async throws {
        print("SyncService: Getting subscriptions from server")
        
        // Get subscriptions from server
        let response = try await apiClient.getSubscriptions(
            serverURL: config.serverURL,
            apiKey: apiKey
        )
        print("SyncService: Got \(response.podcasts.count) subscriptions from server")

        // Get local subscriptions
        let localDescriptor = FetchDescriptor<Podcast>(
            predicate: #Predicate { $0.isSubscribed }
        )
        let localPodcasts = try modelContext.fetch(localDescriptor)
        let localFeedURLs = Set(localPodcasts.map { $0.feedURL })
        print("SyncService: Found \(localFeedURLs.count) local subscriptions")

        // Process server subscriptions
        for serverPodcast in response.podcasts {
            let feedURL = serverPodcast.feedUrl
            
            if let localPodcast = localPodcasts.first(where: { $0.feedURL == feedURL }) {
                // Update server ID if we don't have it
                if localPodcast.serverPodcastId == nil {
                    localPodcast.serverPodcastId = serverPodcast.id
                }
                localPodcast.needsSync = false
                print("SyncService: Updated existing podcast: \(feedURL)")
            } else {
                // Subscribe to new podcast from server
                print("SyncService: Subscribing to new podcast from server: \(feedURL)")
                do {
                    let podcast = try await subscribeFromServer(
                        feedURL: feedURL,
                        serverPodcast: serverPodcast
                    )
                    print("SyncService: Successfully subscribed to: \(podcast.title)")
                } catch {
                    print("SyncService: Failed to subscribe to \(feedURL): \(error)")
                }
            }
        }

        // Upload local-only subscriptions to server
        let serverFeedURLs = Set(response.podcasts.map { $0.feedUrl })
        let localOnlyPodcasts = localPodcasts.filter { 
            $0.needsSync && $0.isSubscribed && !serverFeedURLs.contains($0.feedURL)
        }
        
        for podcast in localOnlyPodcasts {
            print("SyncService: Uploading local subscription to server: \(podcast.feedURL)")
            do {
                let subscribeResponse = try await apiClient.subscribe(
                    serverURL: config.serverURL,
                    apiKey: apiKey,
                    feedURL: podcast.feedURL
                )
                podcast.serverPodcastId = subscribeResponse.podcast.id
                podcast.needsSync = false
                print("SyncService: Successfully uploaded subscription")
            } catch PodcastServiceAPIError.conflict {
                // Already subscribed on server, just mark as synced
                podcast.needsSync = false
                print("SyncService: Podcast already on server, marked as synced")
            } catch {
                print("SyncService: Failed to upload subscription: \(error)")
            }
        }

        syncState.lastSubscriptionSync = .now
        print("SyncService: Subscription sync completed")
    }
    
    private func subscribeFromServer(
        feedURL: String,
        serverPodcast: SubscribedPodcast
    ) async throws -> Podcast {
        // Check if already exists locally
        let descriptor = FetchDescriptor<Podcast>(
            predicate: #Predicate { $0.feedURL == feedURL }
        )
        
        if let existing = try modelContext.fetch(descriptor).first {
            existing.isSubscribed = true
            existing.serverPodcastId = serverPodcast.id
            existing.needsSync = false
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
            categories: parsed.categories,
            serverPodcastId: serverPodcast.id
        )
        podcast.needsSync = false
        
        modelContext.insert(podcast)
        
        // Create episodes
        for parsedEpisode in parsed.episodes {
            let episode = Episode(
                guid: parsedEpisode.guid,
                podcastFeedURL: feedURL,
                title: parsedEpisode.title,
                audioURL: parsedEpisode.audioURL,
                episodeDescription: parsedEpisode.description,
                showNotesHTML: parsedEpisode.showNotesHTML,
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
        
        return podcast
    }
    
    private func syncProgress(
        config: ServerConfiguration,
        apiKey: String,
        syncState: SyncState
    ) async throws {
        print("SyncService: Getting progress from server")
        
        // Get progress from server
        let response = try await apiClient.getProgress(
            serverURL: config.serverURL,
            apiKey: apiKey
        )
        print("SyncService: Got \(response.progress.count) progress records from server")

        // Apply server progress to local episodes
        for progressRecord in response.progress {
            try await applyProgressFromServer(progressRecord)
        }
        
        // Upload pending local progress
        print("SyncService: Checking for pending progress updates to upload")
        let pendingDescriptor = FetchDescriptor<EpisodeAction>(
            predicate: #Predicate { !$0.isSynced }
        )
        let pendingActions = try modelContext.fetch(pendingDescriptor)
        print("SyncService: Found \(pendingActions.count) pending progress updates")

        if !pendingActions.isEmpty {
            let updates = pendingActions.compactMap { $0.toBulkProgressUpdate() }
            
            if !updates.isEmpty {
                print("SyncService: Uploading \(updates.count) progress updates to server")
                do {
                    let bulkResponse = try await apiClient.bulkUpdateProgress(
                        serverURL: config.serverURL,
                        apiKey: apiKey,
                        updates: updates
                    )
                    
                    // Mark successful uploads as synced
                    for result in bulkResponse.results where result.success {
                        if let action = pendingActions.first(where: { $0.serverEpisodeId == result.episodeId }) {
                            action.isSynced = true
                        }
                    }
                    print("SyncService: Progress upload completed")
                } catch {
                    print("SyncService: Failed to upload progress: \(error)")
                }
            }
        }

        syncState.lastProgressSync = .now
        print("SyncService: Progress sync completed")
    }
    
    private func applyProgressFromServer(_ record: ProgressRecord) async throws {
        // Find the episode by server ID
        let serverEpisodeId = record.episodeId
        let descriptor = FetchDescriptor<Episode>(
            predicate: #Predicate { $0.serverEpisodeId == serverEpisodeId }
        )
        
        if let episode = try modelContext.fetch(descriptor).first {
            // Only update if server is newer
            if episode.lastSyncedAt == nil || record.lastUpdatedAt > episode.lastSyncedAt! {
                episode.playbackPosition = TimeInterval(record.positionSeconds)
                episode.isPlayed = record.completed
                episode.lastSyncedAt = record.lastUpdatedAt
                episode.needsSync = false
                print("SyncService: Updated episode progress from server: \(episode.title)")
            }
            return
        }
        
        // Episode not found by server ID - try to match by audio URL if we have episode info
        if let progressEpisode = record.episode,
           let podcastInfo = progressEpisode.podcast {
            // Find by podcast and title as fallback
            print("SyncService: Episode with server ID \(serverEpisodeId) not found locally")
        }
    }
    
    /// Fetch and sync episode server IDs for a podcast
    func syncEpisodeIds(for podcast: Podcast) async throws {
        guard let serverPodcastId = podcast.serverPodcastId else { return }
        
        let config = try getServerConfiguration()
        guard config.isAuthenticated, let apiKey = config.apiKey else { return }
        
        // Get episodes from server
        let response = try await apiClient.getEpisodes(
            serverURL: config.serverURL,
            apiKey: apiKey,
            podcastId: serverPodcastId,
            limit: 100,
            offset: nil,
            filter: nil,
            sort: nil
        )
        
        // Match by audio URL
        for serverEpisode in response.episodes {
            let audioURL = serverEpisode.audioUrl
            if let localEpisode = podcast.episodes.first(where: { $0.audioURL == audioURL }) {
                if localEpisode.serverEpisodeId == nil {
                    localEpisode.serverEpisodeId = serverEpisode.id
                }
                
                // Apply progress if available
                if let progress = serverEpisode.progress {
                    localEpisode.playbackPosition = TimeInterval(progress.positionSeconds)
                    localEpisode.isPlayed = progress.completed
                    localEpisode.lastSyncedAt = .now
                }
            }
        }
        
        try modelContext.save()
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
            apiClient: MockPodcastServiceAPIClient(),
            modelContext: container.mainContext
        )
    }
}
