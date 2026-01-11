import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Tab = .library
    @Environment(AudioPlayerService.self) private var playerService
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                LibraryView()
                    .tag(Tab.library)
                    .tabItem {
                        Label("Library", systemImage: "books.vertical")
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
            
            // Mini player shown when something is playing
            if playerService.currentEpisode != nil {
                MiniPlayerView()
                    .padding(.bottom, 49) // Tab bar height
            }
        }
    }
}

enum Tab: Hashable {
    case library
    case search
    case settings
}

#Preview {
    ContentView()
        .environment(AudioPlayerService())
        .environment(SyncService.preview)
}
