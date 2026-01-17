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
           progressEpisode.podcast != nil {
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

    // MARK: - Queue Management

    /// Get the user's listening queue from server and sync with local
    func getQueue() async throws -> [QueueItem] {
        let config = try getServerConfiguration()
        guard config.isAuthenticated, let apiKey = config.apiKey else {
            throw PodcastServiceAPIError.noAPIKey
        }

        let response = try await apiClient.getQueue(serverURL: config.serverURL, apiKey: apiKey)

        // Clear existing local queue
        let localDescriptor = FetchDescriptor<QueueItem>()
        let localQueue = try modelContext.fetch(localDescriptor)
        for item in localQueue {
            modelContext.delete(item)
        }

        // Create local queue items from server response
        var localQueueItems: [QueueItem] = []
        for apiItem in response.queue {
            let queueItem = QueueItem(
                id: UUID().uuidString,
                position: apiItem.position,
                episodeId: apiItem.episodeId,
                serverId: apiItem.id
            )

            // Try to link to local episode if we have it
            if let episodeId = apiItem.episode?.id {
                let episodeDescriptor = FetchDescriptor<Episode>(
                    predicate: #Predicate { $0.serverEpisodeId == episodeId }
                )
                if let episode = try modelContext.fetch(episodeDescriptor).first {
                    queueItem.episode = episode
                }
            }

            queueItem.needsSync = false
            queueItem.lastSyncedAt = .now

            modelContext.insert(queueItem)
            localQueueItems.append(queueItem)
        }

        try modelContext.save()
        return localQueueItems.sorted { $0.position < $1.position }
    }

    /// Add an episode to the queue
    func addToQueue(episode: Episode) async throws {
        let config = try getServerConfiguration()
        guard config.isAuthenticated, let apiKey = config.apiKey else {
            // Store locally if not authenticated
            let queueItem = QueueItem(
                position: getNextQueuePosition(),
                episodeId: episode.id
            )
            queueItem.episode = episode
            modelContext.insert(queueItem)
            try modelContext.save()
            return
        }

        guard let serverEpisodeId = episode.serverEpisodeId else {
            throw PodcastServiceAPIError.validationError(details: "Episode not synced with server")
        }

        let response = try await apiClient.addToQueue(
            serverURL: config.serverURL,
            apiKey: apiKey,
            episodeId: serverEpisodeId
        )

        // Create local queue item
        let queueItem = QueueItem(
            id: UUID().uuidString,
            position: response.queueItem.position,
            episodeId: episode.id,
            serverId: response.queueItem.id
        )
        queueItem.episode = episode
        queueItem.needsSync = false
        queueItem.lastSyncedAt = .now

        modelContext.insert(queueItem)
        try modelContext.save()
    }

    /// Reorder queue items
    func reorderQueue(items: [QueueItem]) async throws {
        let config = try getServerConfiguration()
        guard config.isAuthenticated, let apiKey = config.apiKey else {
            // Update local positions only
            for (index, item) in items.enumerated() {
                item.position = index
            }
            try modelContext.save()
            return
        }

        let reorderItems = items.enumerated().map { index, item in
            QueueReorderItem(id: item.serverId ?? item.id, position: index)
        }

        _ = try await apiClient.reorderQueue(
            serverURL: config.serverURL,
            apiKey: apiKey,
            items: reorderItems
        )

        // Update local positions
        for (index, item) in items.enumerated() {
            item.position = index
            item.lastSyncedAt = .now
        }

        try modelContext.save()
    }

    /// Clear the queue
    func clearQueue(preserveCurrentEpisode: Episode? = nil) async throws {
        let config = try getServerConfiguration()
        guard config.isAuthenticated, let apiKey = config.apiKey else {
            // Clear local queue
            let descriptor = FetchDescriptor<QueueItem>()
            let items = try modelContext.fetch(descriptor)
            for item in items {
                if preserveCurrentEpisode == nil || item.episode?.id != preserveCurrentEpisode?.id {
                    modelContext.delete(item)
                }
            }
            try modelContext.save()
            return
        }

        let currentEpisodeId = preserveCurrentEpisode?.serverEpisodeId

        _ = try await apiClient.clearQueue(
            serverURL: config.serverURL,
            apiKey: apiKey,
            currentEpisodeId: currentEpisodeId
        )

        // Update local queue
        let descriptor = FetchDescriptor<QueueItem>()
        let items = try modelContext.fetch(descriptor)
        for item in items {
            if currentEpisodeId == nil || item.episode?.serverEpisodeId != currentEpisodeId {
                modelContext.delete(item)
            } else {
                item.lastSyncedAt = .now
            }
        }

        try modelContext.save()
    }

    /// Remove an item from the queue
    func removeFromQueue(queueItem: QueueItem) async throws {
        let config = try getServerConfiguration()
        if config.isAuthenticated, let apiKey = config.apiKey, let serverId = queueItem.serverId {
            _ = try await apiClient.removeFromQueue(
                serverURL: config.serverURL,
                apiKey: apiKey,
                queueItemId: serverId
            )
        }

        modelContext.delete(queueItem)
        try modelContext.save()
    }

    // MARK: - Playlist Management

    /// Get all playlists from server and sync with local
    func getPlaylists() async throws -> [Playlist] {
        let config = try getServerConfiguration()
        guard config.isAuthenticated, let apiKey = config.apiKey else {
            // Return local playlists only
            let descriptor = FetchDescriptor<Playlist>()
            return try modelContext.fetch(descriptor)
        }

        let response = try await apiClient.getPlaylists(serverURL: config.serverURL, apiKey: apiKey)

        // Update or create local playlists
        var localPlaylists: [Playlist] = []
        for apiPlaylist in response.playlists {
            let playlist = try await syncPlaylistFromServer(apiPlaylist)
            localPlaylists.append(playlist)
        }

        return localPlaylists
    }

    /// Create a new playlist
    func createPlaylist(name: String, description: String? = nil) async throws -> Playlist {
        let config = try getServerConfiguration()
        guard config.isAuthenticated, let apiKey = config.apiKey else {
            // Create local playlist only
            let playlist = Playlist(name: name, descriptionText: description)
            modelContext.insert(playlist)
            try modelContext.save()
            return playlist
        }

        let response = try await apiClient.createPlaylist(
            serverURL: config.serverURL,
            apiKey: apiKey,
            name: name,
            description: description
        )

        // Create local playlist
        let playlist = Playlist(
            serverId: response.playlist.id,
            name: response.playlist.name,
            descriptionText: response.playlist.description,
            createdAt: response.playlist.createdAt,
            updatedAt: response.playlist.updatedAt
        )
        playlist.needsSync = false
        playlist.lastSyncedAt = .now

        modelContext.insert(playlist)
        try modelContext.save()

        return playlist
    }

    /// Get a specific playlist with its items
    func getPlaylist(id: String) async throws -> Playlist {
        let descriptor = FetchDescriptor<Playlist>(
            predicate: #Predicate { $0.id == id }
        )

        guard let playlist = try modelContext.fetch(descriptor).first else {
            throw PodcastServiceAPIError.notFound
        }

        let config = try getServerConfiguration()
        if config.isAuthenticated, let apiKey = config.apiKey, let serverId = playlist.serverId {
            let response = try await apiClient.getPlaylist(
                serverURL: config.serverURL,
                apiKey: apiKey,
                playlistId: serverId
            )

            // Update local items
            try await syncPlaylistItemsFromServer(playlist, items: response.playlist.items)
            playlist.lastSyncedAt = .now
            try modelContext.save()
        }

        return playlist
    }

    /// Update a playlist
    func updatePlaylist(_ playlist: Playlist, name: String? = nil, description: String? = nil) async throws {
        let config = try getServerConfiguration()
        if config.isAuthenticated, let apiKey = config.apiKey, let serverId = playlist.serverId {
            _ = try await apiClient.updatePlaylist(
                serverURL: config.serverURL,
                apiKey: apiKey,
                playlistId: serverId,
                name: name,
                description: description
            )
        }

        if let name = name {
            playlist.name = name
        }
        if let description = description {
            playlist.descriptionText = description
        }
        playlist.updatedAt = .now
        playlist.lastSyncedAt = .now

        try modelContext.save()
    }

    /// Delete a playlist
    func deletePlaylist(_ playlist: Playlist) async throws {
        let config = try getServerConfiguration()
        if config.isAuthenticated, let apiKey = config.apiKey, let serverId = playlist.serverId {
            _ = try await apiClient.deletePlaylist(
                serverURL: config.serverURL,
                apiKey: apiKey,
                playlistId: serverId
            )
        }

        modelContext.delete(playlist)
        try modelContext.save()
    }

    /// Add an item to a playlist
    func addToPlaylist(_ playlist: Playlist, podcast: Podcast? = nil, episode: Episode? = nil) async throws {
        let config = try getServerConfiguration()
        guard config.isAuthenticated, let apiKey = config.apiKey, let serverPlaylistId = playlist.serverId else {
            // Create local item only
            let position = playlist.items.count
            let item = PlaylistItem(
                position: position,
                podcastId: podcast?.feedURL,
                episodeId: episode?.id
            )
            item.podcast = podcast
            item.episode = episode
            item.playlist = playlist
            modelContext.insert(item)
            try modelContext.save()
            return
        }

        let serverPodcastId = podcast?.serverPodcastId
        let serverEpisodeId = episode?.serverEpisodeId

        guard serverPodcastId != nil || serverEpisodeId != nil else {
            throw PodcastServiceAPIError.validationError(details: "Item not synced with server")
        }

        let response = try await apiClient.addToPlaylist(
            serverURL: config.serverURL,
            apiKey: apiKey,
            playlistId: serverPlaylistId,
            podcastId: serverPodcastId,
            episodeId: serverEpisodeId,
            position: nil
        )

        // Create local item
        let position = playlist.items.count
        let item = PlaylistItem(
            serverId: response.id,
            position: position,
            podcastId: podcast?.feedURL,
            episodeId: episode?.id
        )
        item.podcast = podcast
        item.episode = episode
        item.playlist = playlist
        item.needsSync = false
        item.lastSyncedAt = .now

        modelContext.insert(item)
        try modelContext.save()
    }

    /// Remove an item from a playlist
    func removeFromPlaylist(_ playlist: Playlist, item: PlaylistItem) async throws {
        let config = try getServerConfiguration()
        if config.isAuthenticated,
           let apiKey = config.apiKey,
           let serverPlaylistId = playlist.serverId,
           let serverItemId = item.serverId {
            _ = try await apiClient.removeFromPlaylist(
                serverURL: config.serverURL,
                apiKey: apiKey,
                playlistId: serverPlaylistId,
                itemId: serverItemId
            )
        }

        modelContext.delete(item)

        // Reorder remaining items
        let remainingItems = playlist.items.sorted { $0.position < $1.position }
        for (index, remainingItem) in remainingItems.enumerated() {
            remainingItem.position = index
        }

        try modelContext.save()
    }

    /// Reorder playlist items
    func reorderPlaylistItems(_ playlist: Playlist, items: [PlaylistItem]) async throws {
        // Update local positions
        for (index, item) in items.enumerated() {
            item.position = index
        }

        let config = try getServerConfiguration()
        if config.isAuthenticated, let apiKey = config.apiKey {
            // Update positions on server
            for item in items where item.serverId != nil {
                try await apiClient.updatePlaylistItem(
                    serverURL: config.serverURL,
                    apiKey: apiKey,
                    playlistId: playlist.serverId!,
                    itemId: item.serverId!,
                    position: item.position
                )
            }
        }

        try modelContext.save()
    }

    // MARK: - Private Helpers

    private func getNextQueuePosition() -> Int {
        let descriptor = FetchDescriptor<QueueItem>(
            sortBy: [SortDescriptor(\.position, order: .reverse)]
        )
        let items = try? modelContext.fetch(descriptor)
        return (items?.first?.position ?? -1) + 1
    }

    private func syncPlaylistFromServer(_ apiPlaylist: APIPlaylist) async throws -> Playlist {
        let playlistId = apiPlaylist.id
        let descriptor = FetchDescriptor<Playlist>(
            predicate: #Predicate { $0.serverId == playlistId }
        )

        if let existingPlaylist = try modelContext.fetch(descriptor).first {
            // Update existing playlist
            existingPlaylist.name = apiPlaylist.name
            existingPlaylist.descriptionText = apiPlaylist.description
            existingPlaylist.updatedAt = apiPlaylist.updatedAt
            existingPlaylist.needsSync = false
            existingPlaylist.lastSyncedAt = .now
            return existingPlaylist
        } else {
            // Create new playlist
            let playlist = Playlist(
                serverId: apiPlaylist.id,
                name: apiPlaylist.name,
                descriptionText: apiPlaylist.description,
                createdAt: apiPlaylist.createdAt,
                updatedAt: apiPlaylist.updatedAt
            )
            playlist.needsSync = false
            playlist.lastSyncedAt = .now
            modelContext.insert(playlist)
            return playlist
        }
    }

    private func syncPlaylistItemsFromServer(_ playlist: Playlist, items: [APIModelPlaylistItem]) async throws {
        // Clear existing items
        for item in playlist.items {
            modelContext.delete(item)
        }

        // Add new items
        for apiItem in items {
            let item = PlaylistItem(
                serverId: apiItem.id,
                position: apiItem.position,
                podcastId: apiItem.podcast?.id,
                episodeId: apiItem.episode?.id
            )

            // Try to link to local podcast/episode
            if let podcastId = apiItem.podcast?.id {
                let podcastDescriptor = FetchDescriptor<Podcast>(
                    predicate: #Predicate { $0.serverPodcastId == podcastId }
                )
                item.podcast = try modelContext.fetch(podcastDescriptor).first
            }

            if let episodeId = apiItem.episode?.id {
                let episodeDescriptor = FetchDescriptor<Episode>(
                    predicate: #Predicate { $0.serverEpisodeId == episodeId }
                )
                item.episode = try modelContext.fetch(episodeDescriptor).first
            }

            item.playlist = playlist
            item.needsSync = false
            item.lastSyncedAt = .now

            modelContext.insert(item)
        }
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
            ServerConfiguration.self,
            QueueItem.self,
            Playlist.self,
            PlaylistItem.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        
        return SyncService(
            apiClient: MockPodcastServiceAPIClient(),
            modelContext: container.mainContext
        )
    }
}
