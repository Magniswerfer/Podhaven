import SwiftUI
import SwiftData

// MARK: - Create Playlist View

struct CreatePlaylistView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SyncService.self) private var syncService

    @State private var name = ""
    @State private var descriptionText = ""
    @State private var isLoading = false
    @State private var error: Error?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Playlist Name", text: $name)
                        .autocapitalization(.words)
                }

                Section {
                    TextField("Description (optional)", text: $descriptionText, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Create Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            await createPlaylist()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                }
            }
            .alert("Error", isPresented: .init(get: { error != nil }, set: { _ in error = nil })) {
                Button("OK") {}
            } message: {
                if let error = error {
                    Text(error.localizedDescription)
                }
            }
        }
    }

    private func createPlaylist() async {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            _ = try await syncService.createPlaylist(
                name: name.trimmingCharacters(in: .whitespaces),
                description: descriptionText.trimmingCharacters(in: .whitespaces).isEmpty ? nil : descriptionText
            )
            dismiss()
        } catch {
            self.error = error
        }
    }
}

#Preview {
    CreatePlaylistView()
        .environment(SyncService.preview)
}
