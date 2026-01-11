# Podhaven

A native iOS podcast app with gpodder sync support. The first iOS app to support gpodder synchronization for podcast subscriptions and listening progress.

## Features

- 🎧 **Podcast Management** - Subscribe via RSS URL or search
- 🔄 **gpodder Sync** - Sync subscriptions and listening progress with any gpodder-compatible server
- 📥 **Offline Downloads** - Download episodes for offline listening
- 🎛️ **Background Playback** - Lock screen controls and AirPlay support
- ⚡ **Native Performance** - Built with SwiftUI and Swift Concurrency

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

## Project Setup

1. Open Xcode and create a new project:
   - Choose **App** template
   - Product Name: `Podhaven`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Storage: **SwiftData**

2. Copy the source files from this repository into your Xcode project:
   ```
   Podhaven/
   ├── App/
   │   ├── PodheavenApp.swift
   │   ├── AppDependencies.swift
   │   └── ContentView.swift
   ├── Core/
   │   └── Extensions/
   │       └── View+Extensions.swift
   ├── Models/
   │   ├── Podcast.swift
   │   ├── Episode.swift
   │   ├── EpisodeAction.swift
   │   ├── SyncState.swift
   │   └── ServerConfiguration.swift
   ├── Services/
   │   ├── Network/
   │   │   ├── GpodderAPIClient.swift
   │   │   ├── GpodderAPIModels.swift
   │   │   ├── GpodderAPIError.swift
   │   │   └── MockGpodderAPIClient.swift
   │   ├── RSS/
   │   │   └── RSSParser.swift
   │   ├── Player/
   │   │   └── AudioPlayerService.swift
   │   ├── Download/
   │   │   └── DownloadService.swift
   │   └── Sync/
   │       └── SyncService.swift
   └── Features/
       ├── Library/
       │   ├── LibraryView.swift
       │   ├── PodcastDetailView.swift
       │   └── AddPodcastView.swift
       ├── Search/
       │   └── SearchView.swift
       ├── Settings/
       │   └── SettingsView.swift
       └── NowPlaying/
           ├── NowPlayingView.swift
           └── MiniPlayerView.swift
   ```

3. Add required capabilities in your project settings:
   - **Background Modes**: Audio, AirPlay, and Picture in Picture
   - **Background Modes**: Background fetch (for sync)

4. Update `Info.plist` with required keys:
   ```xml
   <key>UIBackgroundModes</key>
   <array>
       <string>audio</string>
       <string>fetch</string>
   </array>
   ```

## Architecture

### Data Layer
- **SwiftData** models for local persistence
- Protocol-oriented API client for testability
- RSS feed parser for podcast metadata

### Services
- `GpodderAPIClient` - gpodder server communication
- `AudioPlayerService` - AVFoundation-based playback
- `SyncService` - Coordinates sync operations
- `DownloadService` - Background downloads

### UI Layer
- SwiftUI views with `@Observable` view models
- Tab-based navigation (Library, Search, Settings)
- Mini player with full-screen Now Playing view

## gpodder API Integration

The app supports any gpodder-compatible server:

```
POST /api/2/auth/{username}.json     - Authentication
GET  /api/2/subscriptions/{username}.json  - Get subscriptions
POST /api/2/subscriptions/{username}.json  - Update subscriptions
GET  /api/2/episodes/{username}.json       - Get episode actions
POST /api/2/episodes/{username}.json       - Upload episode actions
```

Default server: `https://gpodder.magnus.hk` (configurable in Settings)

## Testing

The project uses protocol-oriented design for easy testing:

```swift
// Use MockGpodderAPIClient in tests
let mockClient = MockGpodderAPIClient()
mockClient.mockSubscriptions = ["https://example.com/feed.xml"]

let syncService = SyncService(
    apiClient: mockClient,
    modelContext: testContext
)
```

## License

MIT License
