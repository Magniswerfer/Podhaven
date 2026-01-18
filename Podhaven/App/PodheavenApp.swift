import SwiftUI
import SwiftData
import BackgroundTasks

@main
struct PodheavenApp: App {
    let container: ModelContainer
    let dependencies: AppDependencies

    // Background task identifier
    static let backgroundSyncTaskIdentifier = "com.podhaven.sync"

    init() {
        do {
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
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            dependencies = AppDependencies(modelContext: container.mainContext)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        // Register background task
        registerBackgroundTasks()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(dependencies.playerService)
                .environment(dependencies.syncService)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    scheduleBackgroundSync()
                }
        }
        .modelContainer(container)
    }

    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.backgroundSyncTaskIdentifier,
            using: nil
        ) { task in
            self.handleBackgroundSync(task: task as! BGAppRefreshTask)
        }
    }

    private func handleBackgroundSync(task: BGAppRefreshTask) {
        // Schedule next background sync
        scheduleBackgroundSync()

        let syncTask = Task { @MainActor in
            do {
                try await dependencies.syncService.performSync()
                task.setTaskCompleted(success: true)
            } catch {
                print("Background sync failed: \(error)")
                task.setTaskCompleted(success: false)
            }
        }

        // Handle task expiration
        task.expirationHandler = {
            syncTask.cancel()
            task.setTaskCompleted(success: false)
        }
    }
}

// Schedule background sync when app goes to background
func scheduleBackgroundSync() {
    let request = BGAppRefreshTaskRequest(identifier: PodheavenApp.backgroundSyncTaskIdentifier)
    // Request to run in 15 minutes (iOS may adjust based on usage patterns)
    request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)

    do {
        try BGTaskScheduler.shared.submit(request)
        print("Background sync scheduled")
    } catch {
        print("Failed to schedule background sync: \(error)")
    }
}
