import AVFoundation
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
    
    // MARK: - Private Properties
    
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var statusObservation: NSKeyValueObservation?
    private var rateObservation: NSKeyValueObservation?
    
    // Callback for saving playback position
    var onPositionUpdate: ((Episode, TimeInterval) async -> Void)?
    
    // MARK: - Initialization
    
    init() {
        setupAudioSession()
        setupRemoteCommands()
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
        
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        
        setupObservers()
        
        // Seek to saved position if any
        if episode.playbackPosition > 0 {
            await seek(to: episode.playbackPosition)
        }
        
        player?.play()
        isPlaying = true
        
        updateNowPlayingInfo()
    }
    
    /// Resume playback
    func resume() {
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
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
    
    // MARK: - Private Methods
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [])
            try session.setActive(true)
        } catch {
            self.error = PlayerError.audioSessionError(error)
        }
    }
    
    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.resume()
            }
            return .success
        }
        
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.pause()
            }
            return .success
        }
        
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.togglePlayPause()
            }
            return .success
        }
        
        center.skipForwardCommand.preferredIntervals = [30]
        center.skipForwardCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                await self?.skipForward()
            }
            return .success
        }
        
        center.skipBackwardCommand.preferredIntervals = [15]
        center.skipBackwardCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                await self?.skipBackward()
            }
            return .success
        }
        
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            Task { @MainActor in
                await self?.seek(to: event.positionTime)
            }
            return .success
        }
    }
    
    private func setupObservers() {
        guard let player = player else { return }
        
        // Time observer - update every 0.5 seconds
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                self?.currentTime = time.seconds
                
                // Update now playing info periodically
                if Int(time.seconds) % 5 == 0 {
                    self?.updateNowPlayingInfo()
                }
            }
        }
        
        // Status observation
        statusObservation = player.currentItem?.observe(\.status) { [weak self] item, _ in
            Task { @MainActor in
                switch item.status {
                case .readyToPlay:
                    self?.isBuffering = false
                    self?.duration = item.duration.seconds
                case .failed:
                    self?.error = item.error ?? PlayerError.playbackFailed
                    self?.isBuffering = false
                default:
                    break
                }
            }
        }
        
        // Rate observation for detecting playback state
        rateObservation = player.observe(\.rate) { [weak self] player, _ in
            Task { @MainActor in
                self?.isPlaying = player.rate > 0
            }
        }
        
        // Notification for playback end
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handlePlaybackEnd()
            }
        }
    }
    
    private func handlePlaybackEnd() {
        isPlaying = false
        currentEpisode?.isPlayed = true
        currentEpisode?.playbackPosition = 0
        
        if let episode = currentEpisode {
            Task {
                await onPositionUpdate?(episode, 0)
            }
        }
    }
    
    private func updateNowPlayingInfo() {
        guard let episode = currentEpisode else { return }
        
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: episode.title,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? playbackRate : 0
        ]
        
        if let podcastTitle = episode.podcast?.title {
            info[MPMediaItemPropertyArtist] = podcastTitle
        }
        
        // Load artwork asynchronously
        if let artworkURLString = episode.effectiveArtworkURL,
           let artworkURL = URL(string: artworkURLString) {
            Task {
                if let (data, _) = try? await URLSession.shared.data(from: artworkURL),
                   let image = UIImage(data: data) {
                    let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                    var updatedInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                    updatedInfo[MPMediaItemPropertyArtwork] = artwork
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = updatedInfo
                }
            }
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
