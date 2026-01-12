import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var serverConfigs: [ServerConfiguration]
    @Query private var syncStates: [SyncState]
    
    @Environment(SyncService.self) private var syncService
    
    private var serverConfig: ServerConfiguration? {
        serverConfigs.first
    }
    
    private var syncState: SyncState? {
        syncStates.first
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Sync Account
                Section("gpodder Sync") {
                    if let config = serverConfig, config.isAuthenticated {
                        authenticatedView(config: config)
                    } else {
                        NavigationLink {
                            LoginView()
                        } label: {
                            Label("Connect to gpodder", systemImage: "link")
                        }
                    }
                }
                
                // Sync Status
                if serverConfig?.isAuthenticated == true {
                    Section("Sync Status") {
                        syncStatusView
                    }
                }
                
                // Playback
                Section("Playback") {
                    NavigationLink {
                        PlaybackSettingsView()
                    } label: {
                        Label("Playback Settings", systemImage: "play.circle")
                    }
                }
                
                // Storage
                Section("Storage") {
                    NavigationLink {
                        StorageSettingsView()
                    } label: {
                        Label("Downloads", systemImage: "arrow.down.circle")
                    }
                }
                
                // About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                    
                    Link(destination: URL(string: "https://github.com")!) {
                        Label("Source Code", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
    
    private func authenticatedView(config: ServerConfiguration) -> some View {
        Group {
            HStack {
                Label("Server", systemImage: "server.rack")
                Spacer()
                Text(config.displayServerURL)
                    .foregroundStyle(.secondary)
            }
            
            HStack {
                Label("Username", systemImage: "person")
                Spacer()
                Text(config.username)
                    .foregroundStyle(.secondary)
            }
            
            Button(role: .destructive) {
                try? syncService.logout()
            } label: {
                Label("Disconnect", systemImage: "link.badge.plus")
            }
        }
    }
    
    @ViewBuilder
    private var syncStatusView: some View {
        if let state = syncState {
            HStack {
                Text("Last Sync")
                Spacer()
                Text(state.lastSyncDescription)
                    .foregroundStyle(.secondary)
            }
            
            if let error = state.lastSyncError {
                HStack {
                    Text("Error")
                    Spacer()
                    Text(error)
                        .foregroundStyle(.red)
                        .lineLimit(1)
                }
            }
        } else {
            HStack {
                Text("Last Sync")
                Spacer()
                Text("Never")
                    .foregroundStyle(.secondary)
            }
        }
        
        Button {
            Task {
                try? await syncService.performSync()
            }
        } label: {
            HStack {
                Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                Spacer()
                if syncService.isSyncing {
                    ProgressView()
                }
            }
        }
        .disabled(syncService.isSyncing)
    }
}

// MARK: - Login View

struct LoginView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SyncService.self) private var syncService
    @FocusState private var focusedField: Field?
    
    @State private var serverURL = "https://gpodder.magnus.hk"
    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var error: Error?
    @State private var showError = false
    
    private enum Field {
        case serverURL, username, password
    }
    
    var body: some View {
        Form {
            Section {
                TextField("Server URL", text: $serverURL)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($focusedField, equals: .serverURL)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .username }
            } header: {
                Text("Server")
            } footer: {
                Text("Enter your gpodder-compatible server URL")
            }
            
            Section("Credentials") {
                TextField("Username", text: $username)
                    .textContentType(.username)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($focusedField, equals: .username)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }
                
                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .focused($focusedField, equals: .password)
                    .submitLabel(.done)
                    .onSubmit {
                        focusedField = nil
                        if !serverURL.isEmpty && !username.isEmpty && !password.isEmpty {
                            Task { await login() }
                        }
                    }
            }
            
            Section {
                Button {
                    focusedField = nil
                    Task {
                        await login()
                    }
                } label: {
                    HStack {
                        Text("Connect")
                        Spacer()
                        if isLoading {
                            ProgressView()
                        }
                    }
                }
                .disabled(serverURL.isEmpty || username.isEmpty || password.isEmpty || isLoading)
            }
        }
        .navigationTitle("Connect to gpodder")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focusedField = nil
                }
            }
        }
        .alert("Login Failed", isPresented: $showError) {
            Button("OK") { }
        } message: {
            if let error = error {
                Text(error.localizedDescription)
            }
        }
    }
    
    private func login() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await syncService.login(
                serverURL: serverURL,
                username: username,
                password: password
            )
            dismiss()
        } catch {
            self.error = error
            showError = true
        }
    }
}

// MARK: - Playback Settings

struct PlaybackSettingsView: View {
    @AppStorage("skipForwardSeconds") private var skipForward = 30
    @AppStorage("skipBackwardSeconds") private var skipBackward = 15
    @AppStorage("defaultPlaybackSpeed") private var playbackSpeed = 1.0
    @AppStorage("continuousPlayback") private var continuousPlayback = true
    
    var body: some View {
        Form {
            Section("Skip Intervals") {
                Stepper("Skip Forward: \(skipForward)s", value: $skipForward, in: 5...120, step: 5)
                Stepper("Skip Backward: \(skipBackward)s", value: $skipBackward, in: 5...60, step: 5)
            }
            
            Section("Speed") {
                Picker("Default Speed", selection: $playbackSpeed) {
                    Text("0.5x").tag(0.5)
                    Text("0.75x").tag(0.75)
                    Text("1x").tag(1.0)
                    Text("1.25x").tag(1.25)
                    Text("1.5x").tag(1.5)
                    Text("1.75x").tag(1.75)
                    Text("2x").tag(2.0)
                }
            }
            
            Section {
                Toggle("Continuous Playback", isOn: $continuousPlayback)
            } footer: {
                Text("Automatically play the next episode when one finishes")
            }
        }
        .navigationTitle("Playback")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Storage Settings

struct StorageSettingsView: View {
    @Environment(DownloadService.self) private var downloadService: DownloadService?
    
    @State private var totalSize: Int64 = 0
    @State private var showDeleteAlert = false
    
    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Downloaded Episodes")
                    Spacer()
                    Text(formattedSize)
                        .foregroundStyle(.secondary)
                }
            }
            
            Section {
                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Label("Delete All Downloads", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Storage")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            totalSize = downloadService?.totalDownloadSize() ?? 0
        }
        .alert("Delete All Downloads", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                try? downloadService?.deleteAllDownloads()
                totalSize = 0
            }
        } message: {
            Text("This will delete all downloaded episodes. You can re-download them later.")
        }
    }
    
    private var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
}

#Preview {
    SettingsView()
        .environment(SyncService.preview)
}
