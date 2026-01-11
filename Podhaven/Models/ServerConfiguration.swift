import Foundation
import SwiftData

/// Stores the gpodder server configuration
@Model
final class ServerConfiguration {
    @Attribute(.unique) var id: String
    
    /// Server details
    var serverURL: String
    var username: String
    
    /// Authentication state
    var isAuthenticated: Bool
    var sessionCookie: String?
    var lastAuthenticatedAt: Date?
    
    /// Device info for gpodder
    var deviceId: String
    var deviceName: String
    
    init(
        serverURL: String = "https://gpodder.magnus.hk",
        username: String = "",
        deviceId: String? = nil,
        deviceName: String = "Podhaven iOS"
    ) {
        self.id = "server-config"
        self.serverURL = serverURL
        self.username = username
        self.isAuthenticated = false
        self.sessionCookie = nil
        self.lastAuthenticatedAt = nil
        self.deviceId = deviceId ?? Self.generateDeviceId()
        self.deviceName = deviceName
    }
    
    private static func generateDeviceId() -> String {
        let uuid = UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "")
        return "podhaven-ios-\(String(uuid.prefix(8)))"
    }
}

// MARK: - Computed Properties

extension ServerConfiguration {
    var baseURL: URL? {
        URL(string: serverURL)
    }
    
    var isConfigured: Bool {
        !serverURL.isEmpty && !username.isEmpty
    }
    
    var displayServerURL: String {
        serverURL
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
    }
}

// MARK: - API Endpoints

extension ServerConfiguration {
    func authURL() -> URL? {
        baseURL?.appendingPathComponent("api/2/auth/\(username).json")
    }
    
    func subscriptionsURL() -> URL? {
        baseURL?.appendingPathComponent("api/2/subscriptions/\(username).json")
    }
    
    func episodeActionsURL() -> URL? {
        baseURL?.appendingPathComponent("api/2/episodes/\(username).json")
    }
    
    func deviceSubscriptionsURL() -> URL? {
        baseURL?.appendingPathComponent("api/2/subscriptions/\(username)/\(deviceId).json")
    }
}
