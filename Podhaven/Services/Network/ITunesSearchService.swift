import Foundation

/// Service for searching podcasts via iTunes Search API
actor ITunesSearchService {
    private let session: URLSession
    private let baseURL = "https://itunes.apple.com/search"
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    /// Search for podcasts by query
    func search(query: String, limit: Int = 25) async throws -> [ITunesPodcastResult] {
        guard !query.isEmpty else { return [] }
        
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "term", value: query),
            URLQueryItem(name: "media", value: "podcast"),
            URLQueryItem(name: "entity", value: "podcast"),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        
        guard let url = components.url else {
            throw ITunesSearchError.invalidURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ITunesSearchError.networkError
        }
        
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw ITunesSearchError.serverError(httpResponse.statusCode)
        }
        
        // Decode outside of actor isolation
        let searchResponse = try Self.decodeResponse(from: data)
        
        // Filter out results without feedUrl (required for subscription)
        return searchResponse.results.filter { $0.feedUrl != nil }
    }
    
    /// Decode response in a nonisolated context
    private nonisolated static func decodeResponse(from data: Data) throws -> ITunesSearchResponse {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ITunesSearchResponse.self, from: data)
    }
}

// MARK: - Response Models

struct ITunesSearchResponse: Decodable, Sendable {
    let resultCount: Int
    let results: [ITunesPodcastResult]
}

struct ITunesPodcastResult: Decodable, Identifiable, Sendable {
    let collectionId: Int
    let trackId: Int?
    let artistName: String?
    let collectionName: String
    let trackName: String?
    let collectionViewUrl: String?
    let feedUrl: String?
    let artworkUrl30: String?
    let artworkUrl60: String?
    let artworkUrl100: String?
    let artworkUrl600: String?
    let releaseDate: String?
    let primaryGenreName: String?
    let genreIds: [String]?
    let genres: [String]?
    let trackCount: Int?
    
    var id: Int { collectionId }
    
    /// Get the best available artwork URL (prefer larger sizes)
    var bestArtworkURL: String? {
        artworkUrl600 ?? artworkUrl100 ?? artworkUrl60 ?? artworkUrl30
    }
    
    /// Display title (prefer collectionName)
    var displayTitle: String {
        collectionName
    }
    
    /// Display author
    var displayAuthor: String? {
        artistName
    }
}

// MARK: - Errors

enum ITunesSearchError: LocalizedError, Sendable {
    case invalidURL
    case networkError
    case serverError(Int)
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid search URL"
        case .networkError:
            return "Network error occurred"
        case .serverError(let code):
            return "Server error: \(code)"
        case .decodingError:
            return "Failed to parse search results"
        }
    }
}

// MARK: - PodcastSearchResult Extension

extension ITunesPodcastResult {
    /// Convert to ITunesSearchResult for use in SearchView
    func toITunesSearchResult() -> ITunesSearchResult? {
        guard let feedURL = feedUrl else { return nil }

        return ITunesSearchResult(
            id: String(collectionId),
            title: displayTitle,
            author: displayAuthor,
            artworkURL: bestArtworkURL,
            feedURL: feedURL,
            genre: primaryGenreName,
            episodeCount: trackCount
        )
    }
}
