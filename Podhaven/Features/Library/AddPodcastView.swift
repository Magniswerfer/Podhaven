import SwiftUI

struct AddPodcastView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SyncService.self) private var syncService
    
    @State private var feedURL = ""
    @State private var isLoading = false
    @State private var error: Error?
    @State private var showError = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("RSS Feed URL", text: $feedURL)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Podcast Feed")
                } footer: {
                    Text("Enter the RSS feed URL of the podcast you want to subscribe to.")
                }
                
                Section {
                    Button {
                        Task {
                            await subscribeToPodcast()
                        }
                    } label: {
                        HStack {
                            Text("Subscribe")
                            Spacer()
                            if isLoading {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(feedURL.isEmpty || isLoading)
                }
            }
            .navigationTitle("Add Podcast")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                if let error = error {
                    Text(error.localizedDescription)
                }
            }
        }
    }
    
    private func subscribeToPodcast() async {
        isLoading = true
        defer { isLoading = false }
        
        // Normalize URL
        var normalizedURL = feedURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalizedURL.hasPrefix("http://") && !normalizedURL.hasPrefix("https://") {
            normalizedURL = "https://" + normalizedURL
        }
        
        do {
            _ = try await syncService.subscribe(to: normalizedURL)
            dismiss()
        } catch {
            self.error = error
            showError = true
        }
    }
}

#Preview {
    AddPodcastView()
        .environment(SyncService.preview)
}
