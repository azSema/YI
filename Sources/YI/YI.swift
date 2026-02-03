import Foundation

/// YI - Swift library for Yi/Kami camera API
///
/// Main entry point for all Yi camera operations.
///
/// ## Usage
/// ```swift
/// // Configure region
/// YI.configure(region: .us)
///
/// // Login
/// let user = try await YI.Auth.login(email: "user@example.com", password: "password")
///
/// // Get devices
/// let devices = try await YI.Device.list()
///
/// // Get profile
/// let profile = try await YI.Account.profile()
/// ```
public enum YI {
    
    // MARK: - Configuration
    
    /// Current region configuration
    public private(set) static var region: Region = .us
    
    /// Configure the library with a specific region
    /// - Parameter region: The region to use for API calls
    public static func configure(region: Region) {
        self.region = region
    }
    
    /// Initialize library and restore session from Keychain if available
    /// Call this in AppDelegate/App init before using any YI methods
    /// - Returns: true if session was restored (user is logged in)
    @discardableResult
    public static func initialize() async -> Bool {
        return await Auth.restoreSession()
    }
    
    // MARK: - Services
    
    /// Authentication service for login, register, logout
    public static let Auth = YIAuthService.shared
    
    /// Device management service for cameras
    public static let Device = YIDeviceService.shared
    
    /// Account/profile management service
    public static let Account = YIAccountService.shared
    
    /// Alerts service for motion detection events
    public static let Alerts = YIAlertService.shared
}

// MARK: - Region

extension YI {
    /// API region configuration
    public enum Region: String, CaseIterable, Sendable {
        case us = "US"
        case eu = "EU"
        case cn = "CN"
        
        /// Base URL for the region
        public var baseURL: String {
            switch self {
            case .us: return "https://gw-us.xiaoyi.com"
            case .eu: return "https://gw-eu.xiaoyi.com"
            case .cn: return "https://gw.xiaoyi.com"
            }
        }
    }
}

// MARK: - Error

extension YI {
    /// YI API errors
    public enum Error: Swift.Error, LocalizedError {
        case notAuthenticated
        case invalidCredentials
        case accountNotActivated
        case emailAlreadyRegistered
        case deviceNotFound
        case deviceNotInPairingMode
        case pairingTimeout
        case networkError(Swift.Error)
        case apiError(code: String, message: String?)
        case decryptionFailed
        case invalidResponse
        
        public var errorDescription: String? {
            switch self {
            case .notAuthenticated:
                return "Not authenticated. Please login first."
            case .invalidCredentials:
                return "Invalid email or password."
            case .accountNotActivated:
                return "Account not activated. Check your email."
            case .emailAlreadyRegistered:
                return "Email already registered."
            case .deviceNotFound:
                return "Device not found."
            case .deviceNotInPairingMode:
                return "Device not in pairing mode."
            case .pairingTimeout:
                return "Pairing timeout. Please try again."
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .apiError(let code, let message):
                return "API error \(code): \(message ?? "Unknown")"
            case .decryptionFailed:
                return "Failed to decrypt media."
            case .invalidResponse:
                return "Invalid response from server."
            }
        }
    }
}
