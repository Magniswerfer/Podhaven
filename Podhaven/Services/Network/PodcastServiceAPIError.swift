import Foundation

enum PodcastServiceAPIError: LocalizedError, Sendable {
    case invalidURL
    case invalidResponse
    case unauthorized
    case forbidden
    case notFound
    case conflict(message: String?)
    case encodingError
    case decodingError(Error)
    case serverError(statusCode: Int, message: String?)
    case networkError(Error)
    case noAPIKey
    case validationError(details: String?)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Invalid email or password"
        case .forbidden:
            return "Access denied"
        case .notFound:
            return "Resource not found"
        case .conflict(let message):
            return message ?? "Resource already exists"
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
        case .noAPIKey:
            return "Not logged in. Please connect your account in Settings."
        case .validationError(let details):
            return details ?? "Invalid request data"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidURL:
            return "Check the server URL in Settings"
        case .unauthorized:
            return "Check your email and password"
        case .forbidden:
            return "You may not have access to this resource"
        case .noAPIKey:
            return "Go to Settings to log in"
        case .networkError:
            return "Check your internet connection"
        case .conflict:
            return "This resource already exists"
        default:
            return nil
        }
    }
}
