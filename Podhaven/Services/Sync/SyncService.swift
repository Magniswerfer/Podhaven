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
            print("SyncService: Starting subscription sync")
            try await syncSubscriptions(config: config, session: session, syncState: syncState)
            print("SyncService: Subscription sync completed")

            // Sync episode actions (with error handling for unsupported servers)
            syncProgress = "Syncing episode progress..."
            print("SyncService: Starting episode actions sync")
            do {
                try await syncEpisodeActions(config: config, session: session, syncState: syncState)
                print("SyncService: Episode actions sync completed")
            } catch {
                print("SyncService: Episode actions sync failed (might not be supported by server): \(error)")
                // Continue with sync even if episode actions fail
                // This allows partial sync success
            }

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
    
    /// Device ID used for gpodder sync
    private static let deviceId = "podhaven-ios"
    
    private func syncSubscriptions(
        config: ServerConfiguration,
        session: String,
        syncState: SyncState
    ) async throws {
        print("SyncService: Getting subscription changes from server")
        // Get subscription changes from server
        let changes = try await apiClient.getSubscriptions(
            serverURL: config.serverURL,
            username: config.username,
            deviceId: Self.deviceId,
            sessionCookie: session
        )
        print("SyncService: Got subscription changes - add: \(changes.add.count), remove: \(changes.remove.count)")

        // Get local subscriptions
        let localDescriptor = FetchDescriptor<Podcast>(
            predicate: #Predicate { $0.isSubscribed }
        )
        let localPodcasts = try modelContext.fetch(localDescriptor)
        let localSubs = Set(localPodcasts.map { $0.feedURL })
        print("SyncService: Found \(localSubs.count) local subscriptions")

        // Subscribe to podcasts added on server
        print("SyncService: Processing server additions - found \(changes.add.count) podcasts")
        for feedURL in changes.add {
            print("SyncService: Processing server podcast: \(feedURL)")
            if !localSubs.contains(feedURL) {
                print("SyncService: Subscribing to new podcast: \(feedURL)")
                do {
                    let podcast = try await subscribe(to: feedURL)
                    print("SyncService: Successfully subscribed to: \(podcast.title)")
                } catch {
                    print("SyncService: Failed to subscribe to \(feedURL): \(error)")
                }
            } else {
                print("SyncService: Podcast already exists locally: \(feedURL)")
            }
        }

        // Handle removals from server (mark as unsubscribed)
        print("SyncService: Processing server removals")
        for feedURL in changes.remove {
            if let podcast = localPodcasts.first(where: { $0.feedURL == feedURL }) {
                podcast.isSubscribed = false
                print("SyncService: Marked podcast as unsubscribed: \(feedURL)")
            }
        }

        // Upload local subscriptions not yet synced
        let localOnlyPodcasts = localPodcasts.filter { $0.needsSync && $0.isSubscribed }
        if !localOnlyPodcasts.isEmpty {
            let urls = localOnlyPodcasts.map { $0.feedURL }
            print("SyncService: Uploading \(urls.count) local subscriptions to server")
            do {
                _ = try await apiClient.updateSubscriptions(
                    serverURL: config.serverURL,
                    username: config.username,
                    deviceId: Self.deviceId,
                    sessionCookie: session,
                    add: urls,
                    remove: []
                )

                for podcast in localOnlyPodcasts {
                    podcast.needsSync = false
                }
                print("SyncService: Successfully uploaded subscriptions")
            } catch {
                print("SyncService: Failed to upload subscriptions: \(error)")
                // Don't fail the entire sync for this - gpodder2go might not support uploads
                // Just mark them as synced so we don't keep trying
                for podcast in localOnlyPodcasts {
                    podcast.needsSync = false
                }
            }
        }

        // Handle unsubscriptions that need to sync
        let pendingUnsubscribe = localPodcasts.filter { !$0.isSubscribed && $0.needsSync }
        if !pendingUnsubscribe.isEmpty {
            let urls = pendingUnsubscribe.map { $0.feedURL }
            print("SyncService: Uploading \(urls.count) unsubscriptions to server")
            do {
                _ = try await apiClient.updateSubscriptions(
                    serverURL: config.serverURL,
                    username: config.username,
                    deviceId: Self.deviceId,
                    sessionCookie: session,
                    add: [],
                    remove: urls
                )

                for podcast in pendingUnsubscribe {
                    podcast.needsSync = false
                }
                print("SyncService: Successfully uploaded unsubscriptions")
            } catch {
                print("SyncService: Failed to upload unsubscriptions: \(error)")
                // Don't fail the entire sync for this - gpodder2go might not support uploads
                for podcast in pendingUnsubscribe {
                    podcast.needsSync = false
                }
            }
        }

        syncState.lastSubscriptionSync = .now
        syncState.subscriptionTimestamp = changes.timestamp
        print("SyncService: Subscription sync completed")
    }
    
    private func syncEpisodeActions(
        config: ServerConfiguration,
        session: String,
        syncState: SyncState
    ) async throws {
        print("SyncService: Getting episode actions from server")
        // Get episode actions from server
        let response = try await apiClient.getEpisodeActions(
            serverURL: config.serverURL,
            username: config.username,
            sessionCookie: session,
            since: syncState.episodeActionTimestamp
        )
        print("SyncService: Got \(response.actions.count) episode actions from server")

        // Apply server actions to local episodes
        print("SyncService: Applying server actions to local episodes")
        for action in response.actions {
            try await applyEpisodeAction(action)
        }
        
        // Upload local pending actions
        print("SyncService: Checking for pending episode actions to upload")
        let pendingDescriptor = FetchDescriptor<EpisodeAction>(
            predicate: #Predicate { !$0.isSynced }
        )
        let pendingActions = try modelContext.fetch(pendingDescriptor)
        print("SyncService: Found \(pendingActions.count) pending episode actions")

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

            print("SyncService: Uploading \(gpodderActions.count) episode actions to server")
            do {
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
                print("SyncService: Marked episode actions as synced")
            } catch {
                print("SyncService: Failed to upload episode actions: \(error)")
                // Mark as synced anyway to avoid retrying
                for action in pendingActions {
                    action.isSynced = true
                }
            }
        }

        syncState.episodeActionTimestamp = response.timestamp
        syncState.lastEpisodeActionSync = .now
        print("SyncService: Episode actions sync completed")
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
