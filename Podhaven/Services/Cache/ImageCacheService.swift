import Foundation
import CryptoKit

/// Service for managing persistent image caching
final class ImageCacheService {
    // MARK: - Types
    
    enum ImageType {
        case podcast
        case episode
    }
    
    // MARK: - Properties
    
    private let fileManager: FileManager
    private let session: URLSession
    
    // MARK: - Initialization
    
    init(fileManager: FileManager = .default, session: URLSession = .shared) {
        self.fileManager = fileManager
        self.session = session
        createCacheDirectories()
    }
    
    // MARK: - Public Methods
    
    /// Cache an image from a URL string
    /// Returns the local file URL if successful, nil otherwise
    func cacheImage(for urlString: String, type: ImageType) async throws -> URL? {
        guard !urlString.isEmpty,
              let remoteURL = URL(string: urlString) else {
            return nil
        }
        
        // Check if already cached
        if let cachedURL = cachedImageURL(for: urlString, type: type) {
            // Verify file still exists
            if fileManager.fileExists(atPath: cachedURL.path) {
                return cachedURL
            }
        }
        
        // Download image
        do {
            let (tempURL, _) = try await session.download(from: remoteURL)
            
            // Get file extension from URL or Content-Type
            let fileExtension = remoteURL.pathExtension.isEmpty ? "jpg" : remoteURL.pathExtension
            
            // Generate cache filename
            let cacheFilename = generateCacheFilename(for: urlString, extension: fileExtension)
            let cacheDirectory = cacheDirectory(for: type)
            let destinationURL = cacheDirectory.appendingPathComponent(cacheFilename)
            
            // Move to cache directory
            try? fileManager.removeItem(at: destinationURL) // Remove if exists
            try fileManager.moveItem(at: tempURL, to: destinationURL)
            
            return destinationURL
        } catch {
            print("ImageCacheService: Failed to cache image from \(urlString): \(error)")
            throw error
        }
    }
    
    /// Get the cached image URL for a given URL string
    /// Returns nil if not cached
    func cachedImageURL(for urlString: String, type: ImageType) -> URL? {
        guard !urlString.isEmpty else { return nil }
        
        // Try to find cached file with any extension
        let cacheDirectory = cacheDirectory(for: type)
        let baseFilename = generateCacheBaseFilename(for: urlString)
        
        // Common image extensions
        let extensions = ["jpg", "jpeg", "png", "gif", "webp"]
        
        for ext in extensions {
            let filename = "\(baseFilename).\(ext)"
            let fileURL = cacheDirectory.appendingPathComponent(filename)
            
            if fileManager.fileExists(atPath: fileURL.path) {
                return fileURL
            }
        }
        
        return nil
    }
    
    /// Calculate total cache size
    func cacheSize() -> Int64 {
        var totalSize: Int64 = 0
        
        let directories = [
            cacheDirectory(for: .podcast),
            cacheDirectory(for: .episode)
        ]
        
        for directory in directories {
            guard let contents = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.fileSizeKey]
            ) else {
                continue
            }
            
            for url in contents {
                let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                totalSize += Int64(size)
            }
        }
        
        return totalSize
    }
    
    /// Clear cache older than specified date
    /// If date is nil, clears all cache
    func clearCache(olderThan date: Date?) throws {
        let directories = [
            cacheDirectory(for: .podcast),
            cacheDirectory(for: .episode)
        ]
        
        for directory in directories {
            guard let contents = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.creationDateKey, .fileSizeKey]
            ) else {
                continue
            }
            
            for url in contents {
                let shouldDelete: Bool
                
                if let date = date {
                    let creationDate = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                    shouldDelete = creationDate < date
                } else {
                    shouldDelete = true
                }
                
                if shouldDelete {
                    try? fileManager.removeItem(at: url)
                }
            }
        }
    }
    
    /// Clean up cache by removing orphaned files and old entries
    func cleanupCache() async throws {
        // Clear cache older than 30 days
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? .distantPast
        try clearCache(olderThan: thirtyDaysAgo)
    }
    
    /// Delete cached image for a specific URL
    func deleteCachedImage(for urlString: String, type: ImageType) throws {
        guard let cachedURL = cachedImageURL(for: urlString, type: type) else {
            return
        }
        
        try fileManager.removeItem(at: cachedURL)
    }
    
    // MARK: - Private Methods
    
    private var cacheBaseDirectory: URL {
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("Cache", isDirectory: true)
            .appendingPathComponent("Images", isDirectory: true)
    }
    
    private func cacheDirectory(for type: ImageType) -> URL {
        let subdirectory = type == .podcast ? "podcasts" : "episodes"
        return cacheBaseDirectory.appendingPathComponent(subdirectory, isDirectory: true)
    }
    
    private func createCacheDirectories() {
        let directories = [
            cacheDirectory(for: .podcast),
            cacheDirectory(for: .episode)
        ]
        
        for directory in directories {
            if !fileManager.fileExists(atPath: directory.path) {
                try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            }
        }
    }
    
    private func generateCacheBaseFilename(for urlString: String) -> String {
        // Use SHA-256 hash of URL for consistent, filesystem-safe filename
        let data = Data(urlString.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    private func generateCacheFilename(for urlString: String, extension ext: String) -> String {
        let baseFilename = generateCacheBaseFilename(for: urlString)
        return "\(baseFilename).\(ext)"
    }
}
