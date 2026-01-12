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
    
    /// Get user's podcast subscriptions for a device
    func getSubscriptions(
        serverURL: String,
        username: String,
        deviceId: String,
        sessionCookie: String
    ) async throws -> SubscriptionChangesResponse
    
    /// Update subscriptions (add/remove podcasts) for a device
    func updateSubscriptions(
        serverURL: String,
        username: String,
        deviceId: String,
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
        // URL-encode the username to handle special characters like @
        guard let encodedUsername = encodeUsername(username),
              let url = URL(string: "\(serverURL)/api/2/auth/\(encodedUsername)/login.json") else {
            throw GpodderAPIError.invalidURL
        }
        
        print("GpodderAPIClient: Attempting login to \(url)")
        
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
        
        print("GpodderAPIClient: Login response status: \(httpResponse.statusCode)")
        if let responseBody = String(data: data, encoding: .utf8) {
            print("GpodderAPIClient: Response body: \(responseBody)")
        }
        print("GpodderAPIClient: Response headers: \(httpResponse.allHeaderFields)")
        
        // Check for session cookie
        var sessionCookie: String?
        if let cookieHeader = httpResponse.value(forHTTPHeaderField: "Set-Cookie") {
            sessionCookie = cookieHeader
            print("GpodderAPIClient: Got session cookie")
        } else {
            print("GpodderAPIClient: No Set-Cookie header found")
        }
        
        switch httpResponse.statusCode {
        case 200:
            return AuthResponse(
                success: true,
                sessionCookie: sessionCookie,
                message: "Login successful"
            )
        case 401:
            print("GpodderAPIClient: 401 Unauthorized - invalid credentials")
            throw GpodderAPIError.unauthorized
        default:
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("GpodderAPIClient: Unexpected status \(httpResponse.statusCode): \(message)")
            throw GpodderAPIError.serverError(statusCode: httpResponse.statusCode, message: message)
        }
    }
    
    func getSubscriptions(
        serverURL: String,
        username: String,
        deviceId: String,
        sessionCookie: String
    ) async throws -> SubscriptionChangesResponse {
        // Try device-specific endpoint first
        guard let encodedUsername = encodeUsername(username),
              let encodedDeviceId = encodeUsername(deviceId) else {
            throw GpodderAPIError.invalidURL
        }

        var url = URL(string: "\(serverURL)/api/2/subscriptions/\(encodedUsername)/\(encodedDeviceId).json")
        if url == nil {
            throw GpodderAPIError.invalidURL
        }

        print("GpodderAPIClient: Trying device-specific subscriptions from \(url!)")

        var request = URLRequest(url: url!)
        request.httpMethod = "GET"
        request.setValue(sessionCookie, forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            print("GpodderAPIClient: getSubscriptions status: \(httpResponse.statusCode)")

            // If device-specific endpoint returns 404 or 400 (not supported), try without device
            if httpResponse.statusCode == 404 || httpResponse.statusCode == 400 {
                print("GpodderAPIClient: Device-specific endpoint not supported (status \(httpResponse.statusCode)), trying without device ID")
                return try await getSubscriptionsWithoutDevice(serverURL: serverURL, username: username, sessionCookie: sessionCookie)
            }

            if let body = String(data: data, encoding: .utf8) {
                print("GpodderAPIClient: getSubscriptions response: \(body)")
            }
        }

        try validateResponse(response)

        return try decoder.decode(SubscriptionChangesResponse.self, from: data)
    }

    /// Fallback method for servers that don't support device-specific subscriptions
    private func getSubscriptionsWithoutDevice(
        serverURL: String,
        username: String,
        sessionCookie: String
    ) async throws -> SubscriptionChangesResponse {
        guard let encodedUsername = encodeUsername(username) else {
            throw GpodderAPIError.invalidURL
        }

        // Try multiple possible endpoint formats for gpodder2go
        let possibleEndpoints = [
            "\(serverURL)/api/2/subscriptions/\(encodedUsername).json",
            "\(serverURL)/subscriptions/\(encodedUsername).json",
            "\(serverURL)/api/2/subscriptions/\(encodedUsername)",
            "\(serverURL)/subscriptions/\(encodedUsername)"
        ]

        for endpoint in possibleEndpoints {
            guard let url = URL(string: endpoint) else { continue }
            print("GpodderAPIClient: Trying endpoint: \(url)")

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue(sessionCookie, forHTTPHeaderField: "Cookie")
            request.setValue("application/json", forHTTPHeaderField: "Accept")

            do {
                let (data, response) = try await session.data(for: request)

                if let httpResponse = response as? HTTPURLResponse {
                    print("GpodderAPIClient: Endpoint \(endpoint) status: \(httpResponse.statusCode)")
                    if let body = String(data: data, encoding: .utf8) {
                        print("GpodderAPIClient: Response body: \(body)")
                    }

                    // Success!
                    if httpResponse.statusCode == 200 {
                        try validateResponse(response)

                        // Check if response is OPML format (XML)
                        if let bodyString = String(data: data, encoding: .utf8),
                           bodyString.contains("<opml") {
                            print("GpodderAPIClient: Got OPML response, parsing for feed URLs")
                            print("GpodderAPIClient: Full OPML content: \(bodyString)")

                            // Parse OPML to extract feed URLs
                            let feedURLs = parseOPMLForFeedURLs(from: bodyString)
                            print("GpodderAPIClient: Parsed feed URLs: \(feedURLs)")
                            return SubscriptionChangesResponse(
                                add: feedURLs,
                                remove: [],
                                timestamp: Int64(Date().timeIntervalSince1970)
                            )
                        }

                        // If we get a 200 but can't parse it, return empty (no subscriptions)
                        if httpResponse.statusCode == 200 {
                            print("GpodderAPIClient: Got 200 but couldn't parse response, assuming no subscriptions")
                            return SubscriptionChangesResponse(
                                add: [],
                                remove: [],
                                timestamp: Int64(Date().timeIntervalSince1970)
                            )
                        }

                        // Try JSON formats
                        // If we get a simple array, wrap it in the expected format
                        if let array = try? decoder.decode([String].self, from: data) {
                            return SubscriptionChangesResponse(
                                add: array,
                                remove: [],
                                timestamp: Int64(Date().timeIntervalSince1970)
                            )
                        }

                        // Otherwise, try to decode as the full response
                        return try decoder.decode(SubscriptionChangesResponse.self, from: data)
                    }
                }
            } catch {
                print("GpodderAPIClient: Endpoint \(endpoint) failed: \(error)")
                continue
            }
        }

        // All endpoints failed
        throw GpodderAPIError.notFound
    }
    
    func updateSubscriptions(
        serverURL: String,
        username: String,
        deviceId: String,
        sessionCookie: String,
        add: [String],
        remove: [String]
    ) async throws -> SubscriptionUpdateResponse {
        guard let encodedUsername = encodeUsername(username),
              let encodedDeviceId = encodeUsername(deviceId) else {
            throw GpodderAPIError.invalidURL
        }

        // Try device-specific endpoint first
        let url = URL(string: "\(serverURL)/api/2/subscriptions/\(encodedUsername)/\(encodedDeviceId).json")
        if let url = url {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue(sessionCookie, forHTTPHeaderField: "Cookie")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let body = SubscriptionUpdateRequest(add: add, remove: remove)
            request.httpBody = try encoder.encode(body)

            let (data, response) = try await session.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                // If device-specific endpoint returns 404 or 400 (not supported), try without device
                if httpResponse.statusCode == 404 || httpResponse.statusCode == 400 {
                    return try await updateSubscriptionsWithoutDevice(
                        serverURL: serverURL,
                        username: username,
                        sessionCookie: sessionCookie,
                        add: add,
                        remove: remove
                    )
                }
            }

            try validateResponse(response)
            return try decoder.decode(SubscriptionUpdateResponse.self, from: data)
        }

        // URL creation failed, try fallback
        return try await updateSubscriptionsWithoutDevice(
            serverURL: serverURL,
            username: username,
            sessionCookie: sessionCookie,
            add: add,
            remove: remove
        )
    }
    
    func getEpisodeActions(
        serverURL: String,
        username: String,
        sessionCookie: String,
        since: Int64?
    ) async throws -> EpisodeActionsResponse {
        guard let encodedUsername = encodeUsername(username) else {
            throw GpodderAPIError.invalidURL
        }
        
        var urlString = "\(serverURL)/api/2/episodes/\(encodedUsername).json"
        if let since = since {
            urlString += "?since=\(since)"
        }
        
        guard let url = URL(string: urlString) else {
            throw GpodderAPIError.invalidURL
        }
        
        print("GpodderAPIClient: Getting episode actions from \(url)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(sessionCookie, forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await session.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("GpodderAPIClient: getEpisodeActions status: \(httpResponse.statusCode)")
            if let body = String(data: data, encoding: .utf8) {
                print("GpodderAPIClient: getEpisodeActions response: \(body)")
            }
        }
        
        try validateResponse(response)
        
        return try decoder.decode(EpisodeActionsResponse.self, from: data)
    }
    
    func uploadEpisodeActions(
        serverURL: String,
        username: String,
        sessionCookie: String,
        actions: [GpodderEpisodeAction]
    ) async throws -> EpisodeActionsUploadResponse {
        guard let encodedUsername = encodeUsername(username),
              let url = URL(string: "\(serverURL)/api/2/episodes/\(encodedUsername).json") else {
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

    /// Parse OPML XML to extract RSS feed URLs
    private func parseOPMLForFeedURLs(from opmlString: String) -> [String] {
        var feedURLs: [String] = []

        // Simple regex to find xmlUrl attributes in outline elements
        let pattern = #"xmlUrl="([^"]*)""#
        let regex = try? NSRegularExpression(pattern: pattern, options: [])

        if let regex = regex {
            let nsString = opmlString as NSString
            let matches = regex.matches(in: opmlString, options: [], range: NSRange(location: 0, length: nsString.length))

            for match in matches {
                if match.numberOfRanges > 1 {
                    let urlRange = match.range(at: 1)
                    let url = nsString.substring(with: urlRange)
                    feedURLs.append(url)
                }
            }
        }

        print("GpodderAPIClient: Extracted \(feedURLs.count) feed URLs from OPML")
        for (index, url) in feedURLs.enumerated() {
            print("GpodderAPIClient:   [\(index)]: \(url)")
        }
        return feedURLs
    }

    /// Fallback method for servers that don't support device-specific subscription updates
    private func updateSubscriptionsWithoutDevice(
        serverURL: String,
        username: String,
        sessionCookie: String,
        add: [String],
        remove: [String]
    ) async throws -> SubscriptionUpdateResponse {
        guard let encodedUsername = encodeUsername(username) else {
            throw GpodderAPIError.invalidURL
        }

        // Try multiple possible endpoints for updates
        let possibleEndpoints = [
            "\(serverURL)/api/2/subscriptions/\(encodedUsername).json",
            "\(serverURL)/subscriptions/\(encodedUsername).json"
        ]

        for endpoint in possibleEndpoints {
            guard let url = URL(string: endpoint) else { continue }
            print("GpodderAPIClient: Trying subscription update to \(url)")

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue(sessionCookie, forHTTPHeaderField: "Cookie")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let body = SubscriptionUpdateRequest(add: add, remove: remove)
            request.httpBody = try encoder.encode(body)

            do {
                let (data, response) = try await session.data(for: request)

                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    try validateResponse(response)
                    return try decoder.decode(SubscriptionUpdateResponse.self, from: data)
                }
            } catch {
                print("GpodderAPIClient: Update endpoint \(endpoint) failed: \(error)")
                continue
            }
        }

        // All endpoints failed
        throw GpodderAPIError.serverError(statusCode: 0, message: "All subscription update endpoints failed")
    }

    /// URL-encode username for use in URL paths (encodes @ and other special chars)
    private func encodeUsername(_ username: String) -> String? {
        var allowedCharacters = CharacterSet.alphanumerics
        allowedCharacters.insert(charactersIn: "-_.")
        return username.addingPercentEncoding(withAllowedCharacters: allowedCharacters)
    }
    
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
