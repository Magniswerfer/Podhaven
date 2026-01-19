import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Tab = .dashboard
    @State private var shouldFocusSearch = false
    @Environment(AudioPlayerService.self) private var playerService
    @Environment(SyncService.self) private var syncService
    @Environment(\.scenePhase) private var scenePhase

    // Timer for periodic sync (every 5 minutes while active)
    @State private var syncTimer: Timer?

    /// Custom binding that detects re-tapping the search tab
    private var tabSelection: Binding<Tab> {
        Binding(
            get: { selectedTab },
            set: { newValue in
                if newValue == .search && selectedTab == .search {
                    // Re-tapped search tab - focus the search bar
                    shouldFocusSearch = true
                }
                selectedTab = newValue
            }
        )
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: tabSelection) {
                DashboardView()
                    .tag(Tab.dashboard)
                    .tabItem {
                        Label("Dashboard", systemImage: "house")
                    }

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

                SearchView(shouldFocusSearch: $shouldFocusSearch)
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
                    .padding(.bottom, 49)  // Tab bar height
            }
        }
        .task {
            // Full sync on app launch
            await performSyncIfNeeded(mode: .full)
            startPeriodicSync()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            switch newPhase {
            case .active:
                // App became active - smart sync and start timer
                Task {
                    await performSyncIfNeeded(mode: .smart)
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

    private func performSyncIfNeeded(mode: SyncMode = .smart) async {
        do {
            try await syncService.performSync(mode: mode)
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
        // Quick sync every 5 minutes while app is active (smart mode will upgrade to full if needed)
        syncTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            Task { @MainActor in
                await performSyncIfNeeded(mode: .smart)
            }
        }
    }

    private func stopPeriodicSync() {
        syncTimer?.invalidate()
        syncTimer = nil
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = Int(time) / 60 % 60
        let seconds = Int(time) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

enum Tab: Hashable {
    case dashboard
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
