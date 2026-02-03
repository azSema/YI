import Foundation
import os.log

private let logger = Logger(subsystem: "com.yi.YI", category: "AccountService")

/// Account/Profile management service
///
/// Handles user profile and settings.
///
/// ## Usage
/// ```swift
/// // Get profile
/// let props = try await YI.Account.properties()
///
/// // Update settings
/// try await YI.Account.updateExtInfo(timezone: "Europe/London", language: "en-US")
/// ```
public final class YIAccountService: @unchecked Sendable {
    
    /// Shared instance
    public static let shared = YIAccountService()
    
    private let apiClient = YIAPIClient.shared
    
    private init() {}
    
    // MARK: - Properties
    
    /// Get user properties
    /// - Returns: User properties dictionary
    /// - Throws: YI.Error on failure
    public func properties() async throws -> [String: Any] {
        guard let userId = await apiClient.userId else {
            throw YI.Error.notAuthenticated
        }
        
        logger.info("👤 Getting user properties...")
        
        let endpoint = AccountEndpoint.properties(userId: userId)
        let response = try await apiClient.request(
            endpoint: endpoint.path,
            method: endpoint.method,
            orderedParams: endpoint.orderedParams,
            needsAuth: true
        )
        
        guard let data = response["data"] as? [String: Any] else {
            throw YI.Error.invalidResponse
        }
        
        return data
    }
    
    // MARK: - Update
    
    /// Update extended info (timezone, language, location)
    /// - Parameters:
    ///   - timezone: Timezone string (e.g., "Europe/Moscow")
    ///   - language: Language code (e.g., "en-US", "ru-RU")
    ///   - location: Location code (e.g., "US")
    /// - Throws: YI.Error on failure
    public func updateExtInfo(
        timezone: String,
        language: String,
        location: String? = nil
    ) async throws {
        guard let userId = await apiClient.userId else {
            throw YI.Error.notAuthenticated
        }
        
        logger.info("👤 Updating ext info: tz=\(timezone), lang=\(language)")
        
        let endpoint = AccountEndpoint.updateExtInfo(
            userId: userId,
            timezone: timezone,
            language: language,
            location: location ?? YI.region.rawValue
        )
        
        _ = try await apiClient.request(
            endpoint: endpoint.path,
            method: endpoint.method,
            orderedParams: endpoint.orderedParams,
            needsAuth: true
        )
        
        logger.info("✅ Ext info updated")
    }
    
    // MARK: - Login History
    
    /// Get login history
    /// - Parameter days: Number of days to look back (default: 30)
    /// - Returns: Array of login info dictionaries
    /// - Throws: YI.Error on failure
    public func loginHistory(days: Int = 30) async throws -> [[String: Any]] {
        guard let userId = await apiClient.userId else {
            throw YI.Error.notAuthenticated
        }
        
        logger.info("👤 Getting login history...")
        
        let now = Int(Date().timeIntervalSince1970)
        let startTime = now - (days * 24 * 60 * 60)
        
        let endpoint = AccountEndpoint.loginHistory(
            userId: userId,
            startTime: startTime,
            endTime: now
        )
        
        let response = try await apiClient.request(
            endpoint: endpoint.path,
            method: endpoint.method,
            orderedParams: endpoint.orderedParams,
            needsAuth: true
        )
        
        guard let data = response["data"] as? [[String: Any]] else {
            return []
        }
        
        return data
    }
}
