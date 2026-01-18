import AVFoundation

enum SleepTimerSetting {
    case off
    case endOfEpisode
    case minutes(Int)
}

import MediaPlayer
import Observation

/// Audio player service for podcast playback
@Observable
@MainActor
final class AudioPlayerService {
    // MARK: - Published State

    private(set) var currentEpisode: Episode?
    private(set) var isPlaying = false
    private(set) var isBuffering = false
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    private(set) var playbackRate: Float = 1.0
    private(set) var error: Error?
    private(set) var isSleepTimerActive = false
    private(set) var sleepTimerEndDate: Date?

    // MARK: - Private Properties

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var statusObservation: NSKeyValueObservation?
    private var rateObservation: NSKeyValueObservation?
    private var sleepTimer: Timer?
    private var sleepTimerSetting: SleepTimerSetting = .off
    private var artworkImage: UIImage?

    // Callbacks for progress tracking
    var onPositionUpdate: ((Episode, TimeInterval) async -> Void)?
    var onPlaybackCompleted: ((Episode) async -> Void)?

    // MARK: - Initialization

    init() {
        configureAudioSession()
        setupRemoteCommands()
        setupInterruptionHandling()
        setupRouteChangeHandling()
    }

    deinit {
        Task { @MainActor [weak self] in
            self?.cleanup()
        }
    }

    // MARK: - Public Methods

    /// Play an episode
    func play(_ episode: Episode) async {
        guard let url = episode.playbackURL else {
            error = PlayerError.invalidURL
            return
        }

        // Save position of current episode before switching
        if let currentEpisode = currentEpisode, currentTime > 0 {
            await onPositionUpdate?(currentEpisode, currentTime)
        }

        cleanup()
        currentEpisode = episode
        isBuffering = true
        error = nil

        // Activate audio session before creating player
        activateAudioSession()

        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        
        // Important for audio-only apps - prevents video routing issues
        player?.allowsExternalPlayback = false

        setupObservers()

        // Pre-load artwork before starting playback
        await loadArtwork(for: episode)

        // Seek to saved position if any
        if episode.playbackPosition > 0 {
            await seek(to: episode.playbackPosition)
        }

        // Update Now Playing info BEFORE starting playback
        updateNowPlayingInfo()

        player?.play()
        isPlaying = true

        // Update again after starting to reflect playing state
        updateNowPlayingInfo()
    }

    /// Resume playback
    func resume() {
        activateAudioSession()
        player?.play()
        isPlaying = true
        updateNowPlayingInfo()
    }

    /// Pause playback
    func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlayingInfo()

        // Save position
        if let episode = currentEpisode {
            Task {
                await onPositionUpdate?(episode, currentTime)
            }
        }
    }

    /// Toggle play/pause
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            resume()
        }
    }

    /// Seek to a specific time
    func seek(to time: TimeInterval) async {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        await player?.seek(to: cmTime)
        currentTime = time
        updateNowPlayingInfo()
    }

    /// Skip forward by seconds
    func skipForward(_ seconds: TimeInterval = 30) async {
        let newTime = min(currentTime + seconds, duration)
        await seek(to: newTime)
    }

    /// Skip backward by seconds
    func skipBackward(_ seconds: TimeInterval = 15) async {
        let newTime = max(currentTime - seconds, 0)
        await seek(to: newTime)
    }

    /// Set playback speed
    func setPlaybackRate(_ rate: Float) {
        playbackRate = rate
        player?.rate = isPlaying ? rate : 0
        updateNowPlayingInfo()
    }

    /// Set a sleep timer
    func setSleepTimer(for setting: SleepTimerSetting) {
        sleepTimer?.invalidate()
        sleepTimer = nil
        sleepTimerSetting = setting
        isSleepTimerActive = false
        sleepTimerEndDate = nil

        switch setting {
        case .off, .endOfEpisode:
            isSleepTimerActive = setting == .endOfEpisode
        case .minutes(let minutes):
            isSleepTimerActive = true
            let fireDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
            sleepTimerEndDate = fireDate
            sleepTimer = Timer.scheduledTimer(withTimeInterval: fireDate.timeIntervalSinceNow, repeats: false) { [weak self] _ in
                self?.pause()
                self?.setSleepTimer(for: .off)
            }
        }
    }

    /// Stop playback and clear current episode
    func stop() {
        if let episode = currentEpisode {
            Task {
                await onPositionUpdate?(episode, currentTime)
            }
        }

        cleanup()
        currentEpisode = nil
        currentTime = 0
        duration = 0
        isPlaying = false
        isBuffering = false
        artworkImage = nil
        setSleepTimer(for: .off)

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        
        // Deactivate audio session when stopping
        deactivateAudioSession()
    }

    // MARK: - Private Methods
    
    /// Configure audio session category (called once at init)
    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [])
        } catch {
            print("AudioPlayerService: Failed to configure audio session: \(error)")
        }
    }

    /// Activate audio session for playback
    private func activateAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            // Ensure category is set (in case it was reset)
            if session.category != .playback {
                try session.setCategory(.playback, mode: .spokenAudio, options: [])
            }
            try session.setActive(true, options: [])
        } catch {
            print("AudioPlayerService: Failed to activate audio session: \(error)")
            // Don't set self.error here - playback might still work
        }
    }
    
    private func deactivateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("AudioPlayerService: Failed to deactivate audio session: \(error)")
        }
    }
    
    /// Handle audio interruptions (phone calls, other apps, etc.)
    private func setupInterruptionHandling() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let userInfo = notification.userInfo,
                  let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
                return
            }
            
            // Extract options value before Task to avoid capturing non-Sendable userInfo
            let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt
            
            Task { @MainActor [weak self] in
                guard let self else { return }
                
                switch type {
                case .began:
                    // Interruption began - pause playback
                    if self.isPlaying {
                        self.player?.pause()
                        self.isPlaying = false
                        self.updateNowPlayingInfo()
                    }
                    
                case .ended:
                    // Interruption ended - check if we should resume
                    if let optionsValue {
                        let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                        if options.contains(.shouldResume) {
                            self.activateAudioSession()
                            self.player?.play()
                            self.isPlaying = true
                            self.updateNowPlayingInfo()
                        }
                    }
                    
                @unknown default:
                    break
                }
            }
        }
    }

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        
        // Enable and configure play command
        center.playCommand.isEnabled = true
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.resume()
            }
            return .success
        }

        // Enable and configure pause command
        center.pauseCommand.isEnabled = true
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.pause()
            }
            return .success
        }

        // Enable and configure toggle play/pause command
        center.togglePlayPauseCommand.isEnabled = true
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.togglePlayPause()
            }
            return .success
        }

        // Enable and configure skip forward command
        center.skipForwardCommand.isEnabled = true
        center.skipForwardCommand.preferredIntervals = [30]
        center.skipForwardCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                await self?.skipForward()
            }
            return .success
        }

        // Enable and configure skip backward command
        center.skipBackwardCommand.isEnabled = true
        center.skipBackwardCommand.preferredIntervals = [15]
        center.skipBackwardCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                await self?.skipBackward()
            }
            return .success
        }

        // Enable and configure seek command
        center.changePlaybackPositionCommand.isEnabled = true
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            Task { @MainActor in
                await self?.seek(to: event.positionTime)
            }
            return .success
        }
        
        // Disable commands we don't support
        center.nextTrackCommand.isEnabled = false
        center.previousTrackCommand.isEnabled = false
        center.seekForwardCommand.isEnabled = false
        center.seekBackwardCommand.isEnabled = false
    }
    
    private func loadArtwork(for episode: Episode) async {
        guard let artworkURLString = episode.effectiveArtworkURL,
              let artworkURL = URL(string: artworkURLString) else {
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: artworkURL)
            if let image = UIImage(data: data) {
                self.artworkImage = image
            }
        } catch {
            print("AudioPlayerService: Failed to load artwork: \(error)")
        }
    }

    private func setupObservers() {
        guard let player = player else { return }

        // Time observer - update every 0.5 seconds
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) {
            [weak self] time in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.currentTime = time.seconds

                // Update now playing info periodically (every 5 seconds)
                if Int(time.seconds) % 5 == 0 {
                    self.updateNowPlayingInfo()
                }
            }
        }

        // Status observation
        statusObservation = player.currentItem?.observe(\.status) { [weak self] item, _ in
            guard let self else { return }
            let itemStatus = item.status
            let itemDuration = item.duration.seconds
            let itemError = item.error
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch itemStatus {
                case .readyToPlay:
                    self.isBuffering = false
                    if itemDuration.isFinite && itemDuration > 0 {
                        self.duration = itemDuration
                    }
                    // Update now playing info once we have the duration
                    self.updateNowPlayingInfo()
                case .failed:
                    self.error = itemError ?? PlayerError.playbackFailed
                    self.isBuffering = false
                default:
                    break
                }
            }
        }

        // Rate observation for detecting playback state
        rateObservation = player.observe(\.rate) { [weak self] observedPlayer, _ in
            guard let self else { return }
            let rate = observedPlayer.rate
            Task { @MainActor [weak self] in
                guard let self else { return }
                let wasPlaying = self.isPlaying
                self.isPlaying = rate > 0
                // Update now playing info when play state changes
                if wasPlaying != self.isPlaying {
                    self.updateNowPlayingInfo()
                }
            }
        }

        // Notification for playback end
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.handlePlaybackEnd()
            }
        }
    }

    private func handlePlaybackEnd() {
        isPlaying = false
        currentEpisode?.isPlayed = true
        currentEpisode?.playbackPosition = 0

        if let episode = currentEpisode {
            Task {
                // Record completion at the episode's duration
                await onPlaybackCompleted?(episode)
                await onPositionUpdate?(episode, episode.duration ?? 0)
            }
        }

        if case .endOfEpisode = sleepTimerSetting {
            pause()
            setSleepTimer(for: .off)
        }
        
        updateNowPlayingInfo()
    }

    private func updateNowPlayingInfo() {
        guard let episode = currentEpisode else { return }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: episode.title,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? Double(playbackRate) : 0.0,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
            MPNowPlayingInfoPropertyIsLiveStream: false,
        ]

        if let podcastTitle = episode.podcast?.title {
            info[MPMediaItemPropertyArtist] = podcastTitle
            info[MPMediaItemPropertyAlbumTitle] = podcastTitle
        }

        // Add artwork if available
        if let image = artworkImage {
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            info[MPMediaItemPropertyArtwork] = artwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func cleanup() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }

        statusObservation?.invalidate()
        statusObservation = nil

        rateObservation?.invalidate()
        rateObservation = nil

        NotificationCenter.default.removeObserver(
            self,
            name: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem
        )

        player?.pause()
        player = nil
    }
    
    /// Handle route changes (headphones disconnected, etc.)
    private func setupRouteChangeHandling() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let userInfo = notification.userInfo,
                  let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
                return
            }
            
            Task { @MainActor [weak self] in
                guard let self else { return }
                
                // Pause when headphones are unplugged
                if reason == .oldDeviceUnavailable {
                    if self.isPlaying {
                        self.pause()
                    }
                }
            }
        }
    }
}

// MARK: - Errors

enum PlayerError: LocalizedError {
    case invalidURL
    case playbackFailed
    case audioSessionError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid audio URL"
        case .playbackFailed:
            return "Playback failed"
        case .audioSessionError(let error):
            return "Audio session error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Preview

extension AudioPlayerService {
    static var preview: AudioPlayerService {
        AudioPlayerService()
    }
}
