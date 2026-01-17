import Foundation
import SwiftData

/// Stores the podcast sync server configuration
@Model
final class ServerConfiguration {
    @Attribute(.unique) var id: String
    
    /// Server details
    var serverURL: String
    var email: String
    
    /// Authentication state
    var isAuthenticated: Bool
    var apiKey: String?
    var lastAuthenticatedAt: Date?
    
    init(
        serverURL: String = "",
        email: String = ""
    ) {
        self.id = "server-config"
        self.serverURL = serverURL
        self.email = email
        self.isAuthenticated = false
        self.apiKey = nil
        self.lastAuthenticatedAt = nil
    }
}

// MARK: - Computed Properties

extension ServerConfiguration {
    var baseURL: URL? {
        URL(string: serverURL)
    }
    
    var isConfigured: Bool {
        !serverURL.isEmpty && !email.isEmpty
    }
    
    var displayServerURL: String {
        serverURL
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
    }
}
