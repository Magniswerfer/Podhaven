import Foundation

enum GpodderAPIError: LocalizedError, Sendable {
    case invalidURL
    case invalidResponse
    case unauthorized
    case notFound
    case encodingError
    case decodingError(Error)
    case serverError(statusCode: Int, message: String?)
    case networkError(Error)
    case noSession
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Invalid username or password"
        case .notFound:
            return "Resource not found"
        case .encodingError:
            return "Failed to encode request"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .serverError(let statusCode, let message):
            if let message = message {
                return "Server error (\(statusCode)): \(message)"
            }
            return "Server error: \(statusCode)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .noSession:
            return "Not logged in. Please configure your gpodder server in Settings."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidURL:
            return "Check the server URL in Settings"
        case .unauthorized:
            return "Check your username and password"
        case .noSession:
            return "Go to Settings to log in"
        case .networkError:
            return "Check your internet connection"
        default:
            return nil
        }
    }
}
