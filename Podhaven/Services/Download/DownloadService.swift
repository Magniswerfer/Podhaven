import Foundation
import Observation

/// Service for managing episode downloads
@Observable
@MainActor
final class DownloadService {
    // MARK: - State
    
    private(set) var activeDownloads: [String: DownloadTask] = [:]
    
    // MARK: - Private Properties
    
    private let session: URLSession
    private let fileManager: FileManager
    
    // MARK: - Initialization
    
    init() {
        let config = URLSessionConfiguration.background(withIdentifier: "com.podhaven.downloads")
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        self.session = URLSession(configuration: config)
        self.fileManager = .default
        
        createDownloadsDirectory()
    }
    
    // MARK: - Public Methods
    
    /// Download an episode
    func download(_ episode: Episode) async throws {
        guard let url = URL(string: episode.audioURL) else {
            throw DownloadError.invalidURL
        }
        
        guard activeDownloads[episode.id] == nil else {
            return // Already downloading
        }
        
        episode.downloadState = .downloading
        episode.downloadProgress = 0
        
        let task = DownloadTask(episodeId: episode.id, url: url)
        activeDownloads[episode.id] = task
        
        do {
            let (tempURL, _) = try await session.download(from: url)
            
            let destinationURL = downloadURL(for: episode)
            try fileManager.moveItem(at: tempURL, to: destinationURL)
            
            episode.localFileURL = destinationURL.path
            episode.downloadState = .downloaded
            episode.downloadProgress = 1.0
            
            activeDownloads.removeValue(forKey: episode.id)
        } catch {
            episode.downloadState = .failed
            activeDownloads.removeValue(forKey: episode.id)
            throw DownloadError.downloadFailed(error)
        }
    }
    
    /// Cancel a download
    func cancelDownload(for episode: Episode) {
        activeDownloads.removeValue(forKey: episode.id)
        episode.downloadState = .notDownloaded
        episode.downloadProgress = 0
    }
    
    /// Delete a downloaded episode
    func deleteDownload(for episode: Episode) throws {
        guard let localPath = episode.localFileURL else { return }
        
        let url = URL(fileURLWithPath: localPath)
        try fileManager.removeItem(at: url)
        
        episode.localFileURL = nil
        episode.downloadState = .notDownloaded
        episode.downloadProgress = 0
    }
    
    /// Get the total size of all downloads
    func totalDownloadSize() -> Int64 {
        let downloadsDir = downloadsDirectory
        guard let contents = try? fileManager.contentsOfDirectory(
            at: downloadsDir,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else {
            return 0
        }
        
        return contents.reduce(0) { total, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return total + Int64(size)
        }
    }
    
    /// Delete all downloads
    func deleteAllDownloads() throws {
        let downloadsDir = downloadsDirectory
        let contents = try fileManager.contentsOfDirectory(
            at: downloadsDir,
            includingPropertiesForKeys: nil
        )
        
        for url in contents {
            try fileManager.removeItem(at: url)
        }
    }
    
    // MARK: - Private Methods
    
    private var downloadsDirectory: URL {
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("Downloads", isDirectory: true)
    }
    
    private func createDownloadsDirectory() {
        let dir = downloadsDirectory
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }
    
    private func downloadURL(for episode: Episode) -> URL {
        let fileName = episode.id.replacingOccurrences(of: "|", with: "_")
            .replacingOccurrences(of: "/", with: "_")
        let ext = URL(string: episode.audioURL)?.pathExtension ?? "mp3"
        return downloadsDirectory.appendingPathComponent("\(fileName).\(ext)")
    }
}

// MARK: - Download Task

struct DownloadTask: Identifiable {
    let id: String
    let episodeId: String
    let url: URL
    var progress: Double = 0
    
    init(episodeId: String, url: URL) {
        self.id = episodeId
        self.episodeId = episodeId
        self.url = url
    }
}

// MARK: - Errors

enum DownloadError: LocalizedError {
    case invalidURL
    case downloadFailed(Error)
    case deleteFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid download URL"
        case .downloadFailed(let error):
            return "Download failed: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "Failed to delete: \(error.localizedDescription)"
        }
    }
}
