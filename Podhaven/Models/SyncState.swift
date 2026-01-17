import Foundation
import SwiftData

/// Tracks the overall sync state with the podcast sync server
@Model
final class SyncState {
    @Attribute(.unique) var id: String
    
    /// Last successful sync timestamps
    var lastSubscriptionSync: Date?
    var lastProgressSync: Date?
    
    /// Sync status
    var isSyncing: Bool
    var lastSyncError: String?
    var lastSyncAttempt: Date?
    
    /// Statistics
    var totalSyncs: Int
    var failedSyncs: Int
    
    init() {
        self.id = "sync-state"
        self.lastSubscriptionSync = nil
        self.lastProgressSync = nil
        self.isSyncing = false
        self.lastSyncError = nil
        self.lastSyncAttempt = nil
        self.totalSyncs = 0
        self.failedSyncs = 0
    }
}

// MARK: - Convenience Methods

extension SyncState {
    var needsInitialSync: Bool {
        lastSubscriptionSync == nil
    }
    
    var lastSyncDescription: String {
        guard let lastSync = [lastSubscriptionSync, lastProgressSync]
            .compactMap({ $0 })
            .max() else {
            return "Never synced"
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastSync, relativeTo: .now)
    }
    
    func markSyncStarted() {
        isSyncing = true
        lastSyncAttempt = .now
        lastSyncError = nil
    }
    
    func markSyncCompleted() {
        isSyncing = false
        totalSyncs += 1
    }
    
    func markSyncFailed(error: String) {
        isSyncing = false
        lastSyncError = error
        failedSyncs += 1
    }
}
