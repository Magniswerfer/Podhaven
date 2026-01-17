# Podhaven

A native iOS podcast app with podcast sync support. Sync your subscriptions and listening progress across devices with a self-hosted podcast sync server.

## Features

- 🎧 **Podcast Management** - Subscribe via RSS URL or search
- 🔄 **Podcast Sync** - Sync subscriptions and listening progress with your self-hosted server
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
   │   │   ├── PodcastServiceAPIClient.swift
   │   │   ├── PodcastServiceAPIModels.swift
   │   │   ├── PodcastServiceAPIError.swift
   │   │   ├── MockPodcastServiceAPIClient.swift
   │   │   └── ITunesSearchService.swift
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
- `PodcastServiceAPIClient` - Podcast sync server communication
- `AudioPlayerService` - AVFoundation-based playback
- `SyncService` - Coordinates sync operations
- `DownloadService` - Background downloads

### UI Layer
- SwiftUI views with `@Observable` view models
- Tab-based navigation (Library, Search, Settings)
- Mini player with full-screen Now Playing view

## Podcast Sync API Integration

The app syncs with a self-hosted podcast sync server using the following endpoints:

### Authentication
```
POST /api/auth/register  - Create new account
POST /api/auth/login     - Login and get API key
```

### Subscriptions
```
GET    /api/podcasts           - Get subscribed podcasts
POST   /api/podcasts/subscribe - Subscribe to a podcast
DELETE /api/podcasts/{id}      - Unsubscribe from a podcast
GET    /api/podcasts/search    - Search for podcasts
```

### Episodes & Progress
```
GET /api/episodes           - Get episodes with pagination
GET /api/progress           - Get all listening progress
PUT /api/progress/{id}      - Update progress for an episode
POST /api/progress          - Bulk update progress
```

Authentication uses Bearer token (API key) in the Authorization header:
```
Authorization: Bearer <api_key>
```

## Testing

The project uses protocol-oriented design for easy testing:

```swift
// Use MockPodcastServiceAPIClient in tests
let mockClient = MockPodcastServiceAPIClient()
mockClient.mockSubscriptions = [
    SubscribedPodcast(
        id: "uuid",
        title: "Test Podcast",
        feedUrl: "https://example.com/feed.xml",
        // ...
    )
]

let syncService = SyncService(
    apiClient: mockClient,
    modelContext: testContext
)
```

## License

MIT License
