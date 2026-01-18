import SwiftUI

struct PodcastSettingsView: View {
    @Bindable var podcast: Podcast
    @Environment(SyncService.self) private var syncService
    @Environment(\.dismiss) private var dismiss
    
    // Local state to manage UI changes before saving
    @State private var localFilter: EpisodeFilterOption
    @State private var localSort: EpisodeSortOption
    @State private var isSaving = false
    @State private var error: Error?
    @State private var showError = false

    // Enums for settings
    enum EpisodeFilterOption: String, CaseIterable, Identifiable {
        case useDefault = "Use Default"
        case all = "All"
        case unplayed = "Unplayed"
        case inProgress = "In Progress"
        
        var id: Self { self }
        
        var apiValue: String? {
            switch self {
            case .useDefault: return nil // `nil` tells the server to use the user's default
            case .all: return "all"
            case .unplayed: return "unplayed"
            case .inProgress: return "in-progress"
            }
        }
    }

    enum EpisodeSortOption: String, CaseIterable, Identifiable {
        case useDefault = "Use Default"
        case newest = "Newest First"
        case oldest = "Oldest First"
        
        var id: Self { self }
        
        var apiValue: String? {
            switch self {
            case .useDefault: return nil // `nil` tells the server to use the user's default
            case .newest: return "newest"
            case .oldest: return "oldest"
            }
        }
    }

    init(podcast: Podcast) {
        self.podcast = podcast
        // Initialize state from model
        _localFilter = State(initialValue: EpisodeFilterOption(apiValue: podcast.customEpisodeFilter) ?? .useDefault)
        _localSort = State(initialValue: EpisodeSortOption(apiValue: podcast.customEpisodeSort) ?? .useDefault)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Episode Filter") {
                    Picker("Filter", selection: $localFilter) {
                        ForEach(EpisodeFilterOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                }
                
                Section("Episode Sort") {
                    Picker("Sort", selection: $localSort) {
                        ForEach(EpisodeSortOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                }
            }
            .navigationTitle("Podcast Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await saveSettings() }
                    }
                    .disabled(isSaving)
                }
            }
            .alert("Save Failed", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(error?.localizedDescription ?? "An unknown error occurred.")
            }
        }
    }
    
    private func saveSettings() async {
        isSaving = true
        
        do {
            try await syncService.updatePodcastSettings(
                for: podcast,
                filter: localFilter.apiValue,
                sort: localSort.apiValue
            )
            dismiss()
        } catch {
            self.error = error
            self.showError = true
            isSaving = false
        }
    }
}

// Helper initializers to map API string values back to our enums
extension PodcastSettingsView.EpisodeFilterOption {
    init?(apiValue: String?) {
        guard let apiValue else { self = .useDefault; return }
        self = Self.allCases.first { $0.apiValue == apiValue } ?? .useDefault
    }
}

extension PodcastSettingsView.EpisodeSortOption {
    init?(apiValue: String?) {
        guard let apiValue else { self = .useDefault; return }
        self = Self.allCases.first { $0.apiValue == apiValue } ?? .useDefault
    }
}