import SwiftUI
import SwiftData

struct QueueView: View {
    @Environment(SyncService.self) private var syncService
    @Query private var queueItems: [QueueItem]

    @State private var isLoading = false
    @State private var error: Error?

    private var sortedQueueItems: [QueueItem] {
        queueItems.sorted { $0.position < $1.position }
    }

    var body: some View {
        NavigationStack {
            Group {
                if queueItems.isEmpty && !isLoading {
                    emptyQueueView
                } else {
                    queueList
                }
            }
            .navigationTitle("Queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !queueItems.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            Task {
                                await clearQueue()
                            }
                        } label: {
                            Text("Clear")
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .task {
                await loadQueue()
            }
            .refreshable {
                await loadQueue()
            }
        }
    }

    private var emptyQueueView: some View {
        ContentUnavailableView {
            Label("Queue Empty", systemImage: "list.bullet")
        } description: {
            Text("Add episodes to your queue to listen to them in order")
        }
    }

    private var queueList: some View {
        List {
            ForEach(sortedQueueItems) { item in
                QueueItemRow(item: item)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            Task {
                                await removeFromQueue(item)
                            }
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
            }
            .onMove { indices, newOffset in
                Task {
                    await reorderQueue(from: indices, to: newOffset)
                }
            }
        }
        .listStyle(.plain)
        .environment(\.editMode, .constant(.active))
    }

    private func loadQueue() async {
        isLoading = true
        defer { isLoading = false }

        do {
            _ = try await syncService.getQueue()
        } catch {
            self.error = error
            print("Failed to load queue: \(error)")
        }
    }

    private func clearQueue() async {
        do {
            try await syncService.clearQueue()
        } catch {
            self.error = error
            print("Failed to clear queue: \(error)")
        }
    }

    private func removeFromQueue(_ item: QueueItem) async {
        do {
            try await syncService.removeFromQueue(queueItem: item)
        } catch {
            self.error = error
            print("Failed to remove from queue: \(error)")
        }
    }

    private func reorderQueue(from source: IndexSet, to destination: Int) async {
        var items = sortedQueueItems
        items.move(fromOffsets: source, toOffset: destination)

        do {
            try await syncService.reorderQueue(items: items)
        } catch {
            self.error = error
            print("Failed to reorder queue: \(error)")
        }
    }
}

// MARK: - Queue Item Row

struct QueueItemRow: View {
    let item: QueueItem

    var body: some View {
        HStack(spacing: 12) {
            // Drag handle
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.secondary)
                .font(.caption)

            // Artwork
            AsyncImage(url: item.episode.map { URL(string: $0.effectiveArtworkURL ?? "") }) { image in
                image
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.2))
                    .overlay {
                        Image(systemName: "waveform")
                            .foregroundStyle(.secondary)
                    }
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(item.episode?.title ?? "Unknown Episode")
                    .font(.headline)
                    .lineLimit(1)

                if let podcastTitle = item.episode?.podcast?.title {
                    Text(podcastTitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let duration = item.episode?.formattedDuration {
                    Text(duration)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Position indicator
            Text("\(item.position + 1)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    QueueView()
        .environment(SyncService.preview)
}