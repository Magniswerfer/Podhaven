import SwiftUI
import SwiftData

@main
struct PodheavenApp: App {
    let container: ModelContainer
    let dependencies: AppDependencies
    
    init() {
        do {
            let schema = Schema([
                Podcast.self,
                Episode.self,
                EpisodeAction.self,
                SyncState.self,
                ServerConfiguration.self
            ])
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            dependencies = AppDependencies(modelContext: container.mainContext)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(dependencies.playerService)
                .environment(dependencies.syncService)
        }
        .modelContainer(container)
    }
}
