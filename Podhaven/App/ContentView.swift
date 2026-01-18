import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Tab = .library
    @Environment(AudioPlayerService.self) private var playerService
    @Environment(SyncService.self) private var syncService
    @Environment(\.scenePhase) private var scenePhase

    // Timer for periodic sync (every 5 minutes while active)
    @State private var syncTimer: Timer?

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                LibraryView()
                    .tag(Tab.library)
                    .tabItem {
                        Label("Library", systemImage: "books.vertical")
                    }

                QueuePlaylistsView()
                    .tag(Tab.queue)
                    .tabItem {
                        Label("Queue", systemImage: "list.bullet")
                    }

                SearchView()
                    .tag(Tab.search)
                    .tabItem {
                        Label("Search", systemImage: "magnifyingglass")
                    }

                SettingsView()
                    .tag(Tab.settings)
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
            }

            // Mini player shown when something is playing (but not on Settings tab)
            if playerService.currentEpisode != nil && selectedTab != .settings {
                MiniPlayerView()
                    .padding(.bottom, 49) // Tab bar height
            }
        }
        .task {
            // Sync on app launch
            await performSyncIfNeeded()
            startPeriodicSync()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            switch newPhase {
            case .active:
                // App became active - sync and start timer
                Task {
                    await performSyncIfNeeded()
                }
                startPeriodicSync()
            case .background:
                // App going to background - sync progress and stop timer
                stopPeriodicSync()
                Task {
                    await syncProgressBeforeBackground()
                }
            case .inactive:
                // Transitioning - stop timer but don't sync yet
                stopPeriodicSync()
            @unknown default:
                break
            }
        }
    }

    private func performSyncIfNeeded() async {
        do {
            try await syncService.performSync()
        } catch {
            print("ContentView: Sync failed: \(error)")
        }
    }

    private func syncProgressBeforeBackground() async {
        // Save current playback position before going to background
        if let episode = playerService.currentEpisode {
            do {
                try await syncService.recordProgress(
                    episode: episode,
                    position: playerService.currentTime,
                    completed: false
                )
            } catch {
                print("ContentView: Failed to save progress before background: \(error)")
            }
        }
    }

    private func startPeriodicSync() {
        stopPeriodicSync()
        // Sync every 5 minutes while app is active
        syncTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            Task { @MainActor in
                await performSyncIfNeeded()
            }
        }
    }

    private func stopPeriodicSync() {
        syncTimer?.invalidate()
        syncTimer = nil
    }
}

enum Tab: Hashable {
    case library
    case queue
    case search
    case settings
}

#Preview {
    ContentView()
        .environment(AudioPlayerService())
        .environment(SyncService.preview)
}
