import Vapor

/// Flash message types supported by the application
enum FlashType: String {
    case error
    case success
    case warning
    case info
}

extension FlashType {
    /// Convert to a CSS class for styling
    var cssClass: String {
        switch self {
        case .error: return "bg-red-100 border-red-400 text-red-700"
        case .success: return "bg-green-100 border-green-400 text-green-700"
        case .warning: return "bg-yellow-100 border-yellow-400 text-yellow-700"
        case .info: return "bg-blue-100 border-blue-400 text-blue-700"
        }
    }
    
    /// Get the icon name for this flash type
    var icon: String {
        switch self {
        case .error: return "exclamation-circle"
        case .success: return "check-circle"
        case .warning: return "exclamation-triangle"
        case .info: return "information-circle"
        }
    }
}

extension Session {
    /// Set a flash message
    func flash(_ type: FlashType, _ message: String) {
        self.data["flash_type"] = type.rawValue
        self.data["flash_message"] = message
    }
}