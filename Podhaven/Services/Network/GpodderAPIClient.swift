import Foundation

// MARK: - Protocol

/// Protocol defining the gpodder API interface for dependency injection and testing
protocol GpodderAPIClientProtocol: Sendable {
    /// Authenticate with the gpodder server
    func login(
        serverURL: String,
        username: String,
        password: String
    ) async throws -> AuthResponse
    
    /// Get user's podcast subscriptions
    func getSubscriptions(
        serverURL: String,
        username: String,
        sessionCookie: String
    ) async throws -> [String]
    
    /// Update subscriptions (add/remove podcasts)
    func updateSubscriptions(
        serverURL: String,
        username: String,
        sessionCookie: String,
        add: [String],
        remove: [String]
    ) async throws -> SubscriptionUpdateResponse
    
    /// Get episode actions since a given timestamp
    func getEpisodeActions(
        serverURL: String,
        username: String,
        sessionCookie: String,
        since: Int64?
    ) async throws -> EpisodeActionsResponse
    
    /// Upload episode actions (play progress, etc.)
    func uploadEpisodeActions(
        serverURL: String,
        username: String,
        sessionCookie: String,
        actions: [GpodderEpisodeAction]
    ) async throws -> EpisodeActionsUploadResponse
}

// MARK: - Implementation

final class GpodderAPIClient: GpodderAPIClientProtocol, Sendable {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    
    init(session: URLSession = .shared) {
        self.session = session
        
        self.decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            // Try ISO8601 first
            if let date = ISO8601DateFormatter().date(from: dateString) {
                return date
            }
            
            // Try timestamp
            if let timestamp = Double(dateString) {
                return Date(timeIntervalSince1970: timestamp)
            }
            
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Invalid date format")
            )
        }
        
        self.encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
    }
    
    func login(
        serverURL: String,
        username: String,
        password: String
    ) async throws -> AuthResponse {
        guard let url = URL(string: "\(serverURL)/api/2/auth/\(username).json") else {
            throw GpodderAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Basic auth
        let credentials = "\(username):\(password)"
        guard let credentialsData = credentials.data(using: .utf8) else {
            throw GpodderAPIError.encodingError
        }
        let base64Credentials = credentialsData.base64EncodedString()
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GpodderAPIError.invalidResponse
        }
        
        // Check for session cookie
        var sessionCookie: String?
        if let cookieHeader = httpResponse.value(forHTTPHeaderField: "Set-Cookie") {
            sessionCookie = cookieHeader
        }
        
        switch httpResponse.statusCode {
        case 200:
            return AuthResponse(
                success: true,
                sessionCookie: sessionCookie,
                message: "Login successful"
            )
        case 401:
            throw GpodderAPIError.unauthorized
        default:
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GpodderAPIError.serverError(statusCode: httpResponse.statusCode, message: message)
        }
    }
    
    func getSubscriptions(
        serverURL: String,
        username: String,
        sessionCookie: String
    ) async throws -> [String] {
        guard let url = URL(string: "\(serverURL)/api/2/subscriptions/\(username).json") else {
            throw GpodderAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(sessionCookie, forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        
        return try decoder.decode([String].self, from: data)
    }
    
    func updateSubscriptions(
        serverURL: String,
        username: String,
        sessionCookie: String,
        add: [String],
        remove: [String]
    ) async throws -> SubscriptionUpdateResponse {
        guard let url = URL(string: "\(serverURL)/api/2/subscriptions/\(username).json") else {
            throw GpodderAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(sessionCookie, forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = SubscriptionUpdateRequest(add: add, remove: remove)
        request.httpBody = try encoder.encode(body)
        
        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        
        return try decoder.decode(SubscriptionUpdateResponse.self, from: data)
    }
    
    func getEpisodeActions(
        serverURL: String,
        username: String,
        sessionCookie: String,
        since: Int64?
    ) async throws -> EpisodeActionsResponse {
        var urlString = "\(serverURL)/api/2/episodes/\(username).json"
        if let since = since {
            urlString += "?since=\(since)"
        }
        
        guard let url = URL(string: urlString) else {
            throw GpodderAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(sessionCookie, forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        
        return try decoder.decode(EpisodeActionsResponse.self, from: data)
    }
    
    func uploadEpisodeActions(
        serverURL: String,
        username: String,
        sessionCookie: String,
        actions: [GpodderEpisodeAction]
    ) async throws -> EpisodeActionsUploadResponse {
        guard let url = URL(string: "\(serverURL)/api/2/episodes/\(username).json") else {
            throw GpodderAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(sessionCookie, forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        request.httpBody = try encoder.encode(actions)
        
        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        
        return try decoder.decode(EpisodeActionsUploadResponse.self, from: data)
    }
    
    // MARK: - Private Helpers
    
    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GpodderAPIError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200..<300:
            return
        case 401:
            throw GpodderAPIError.unauthorized
        case 404:
            throw GpodderAPIError.notFound
        default:
            throw GpodderAPIError.serverError(statusCode: httpResponse.statusCode, message: nil)
        }
    }
}
