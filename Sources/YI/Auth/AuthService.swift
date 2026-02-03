import Foundation
import os.log

private let logger = Logger(subsystem: "com.yi.YI", category: "AuthService")

/// Authentication service for YI API
///
/// Handles login, registration, and session management.
///
/// ## Usage
/// ```swift
/// // Login
/// let user = try await YI.Auth.login(email: "user@example.com", password: "password")
///
/// // Check if logged in
/// if YI.Auth.isLoggedIn {
///     print("Logged in as \(YI.Auth.currentUser?.name ?? "")")
/// }
///
/// // Logout
/// YI.Auth.logout()
/// ```
public final class YIAuthService: @unchecked Sendable {
    
    /// Shared instance
    public static let shared = YIAuthService()
    
    /// Current authenticated user
    public private(set) var currentUser: YIUser?
    
    /// Is user logged in
    public var isLoggedIn: Bool {
        currentUser != nil
    }
    
    private let apiClient = YIAPIClient.shared
    
    private init() {}
    
    // MARK: - Login
    
    /// Login with email and password
    /// - Parameters:
    ///   - email: User email
    ///   - password: Plain text password (will be encrypted)
    ///   - deviceName: Device name (default: "Apple")
    ///   - deviceType: Device type (default: "iPhone")
    ///   - osVersion: OS version (default: "iOS_18.0")
    /// - Returns: Authenticated user
    /// - Throws: YI.Error on failure
    public func login(
        email: String,
        password: String,
        deviceName: String = "Apple",
        deviceType: String = "iPhone",
        osVersion: String = "iOS_18.0"
    ) async throws -> YIUser {
        logger.info("🔐 Logging in: \(email)")
        
        // Check region first
        let regionEndpoint = AuthEndpoint.queryRegion(account: email, country: YI.region.rawValue)
        _ = try await apiClient.request(
            endpoint: regionEndpoint.path,
            method: regionEndpoint.method,
            orderedParams: regionEndpoint.orderedParams,
            needsAuth: false
        )
        
        // Login
        let loginEndpoint = AuthEndpoint.login(
            account: email,
            password: password,
            deviceName: deviceName,
            deviceType: deviceType,
            osVersion: osVersion
        )
        
        let response = try await apiClient.request(
            endpoint: loginEndpoint.path,
            method: loginEndpoint.method,
            orderedParams: loginEndpoint.orderedParams,
            needsAuth: false
        )
        
        guard let data = response["data"] as? [String: Any] else {
            throw YI.Error.invalidResponse
        }
        
        // Parse user
        let jsonData = try JSONSerialization.data(withJSONObject: data)
        let user = try JSONDecoder().decode(YIUser.self, from: jsonData)
        
        // Store credentials in API client
        await apiClient.setCredentials(
            token: user.token,
            tokenSecret: user.tokenSecret,
            userId: user.id
        )
        
        // Save to Keychain for persistence
        YIKeychain.save(user.token, for: .token)
        YIKeychain.save(user.tokenSecret, for: .tokenSecret)
        YIKeychain.save(user.id, for: .userId)
        if let jsonData = try? JSONEncoder().encode(user),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            YIKeychain.save(jsonString, for: .userJson)
        }
        
        self.currentUser = user
        logger.info("✅ Logged in as: \(user.name)")
        
        // Send agreement event
        try? await sendAgreementEvent(userId: user.id)
        
        return user
    }
    
    // MARK: - Register
    
    /// Register new account
    /// - Parameters:
    ///   - email: Email address
    ///   - password: Password (will be encrypted)
    ///   - firstName: First name
    ///   - lastName: Last name
    ///   - mobile: Phone number (optional)
    ///   - mobileRegion: Country code like "UA+380" (optional)
    ///   - language: Language code (default: "en-US")
    ///   - country: Region code (default: current region)
    /// - Throws: YI.Error on failure
    public func register(
        email: String,
        password: String,
        firstName: String,
        lastName: String,
        mobile: String? = nil,
        mobileRegion: String? = nil,
        language: String = "en-US",
        country: String? = nil
    ) async throws {
        logger.info("📝 Registering: \(email)")
        
        let endpoint = AuthEndpoint.register(
            name: "\(firstName) \(lastName)",
            firstName: firstName,
            lastName: lastName,
            account: email,
            password: password,
            mobile: mobile,
            mobileRegion: mobileRegion,
            language: language,
            country: country ?? YI.region.rawValue
        )
        
        _ = try await apiClient.request(
            endpoint: endpoint.path,
            method: endpoint.method,
            orderedParams: endpoint.orderedParams,
            needsAuth: false
        )
        
        logger.info("✅ Registration successful. Check email for activation link.")
    }
    
    // MARK: - Resend Activation
    
    /// Resend activation email
    /// - Parameters:
    ///   - email: Email address
    ///   - password: Password
    /// - Throws: YI.Error on failure
    public func resendActivation(email: String, password: String) async throws {
        logger.info("📧 Resending activation: \(email)")
        
        let endpoint = AuthEndpoint.resendActivation(email: email, password: password)
        
        _ = try await apiClient.request(
            endpoint: endpoint.path,
            method: endpoint.method,
            orderedParams: endpoint.orderedParams,
            needsAuth: false
        )
        
        logger.info("✅ Activation email sent")
    }
    
    // MARK: - Logout
    
    /// Logout current user
    public func logout() {
        logger.info("👋 Logging out")
        currentUser = nil
        YIKeychain.clearAll()
        Task {
            await apiClient.clearCredentials()
        }
    }
    
    // MARK: - Restore Session
    
    /// Restore session from Keychain (called by YI.initialize())
    /// - Returns: true if session restored
    @discardableResult
    internal func restoreSession() async -> Bool {
        guard let token = YIKeychain.load(.token),
              let tokenSecret = YIKeychain.load(.tokenSecret),
              let userId = YIKeychain.load(.userId) else {
            logger.info("🔐 No saved session in Keychain")
            return false
        }
        
        logger.info("🔐 Restoring session from Keychain...")
        
        // Restore credentials to API client
        await apiClient.setCredentials(
            token: token,
            tokenSecret: tokenSecret,
            userId: userId
        )
        
        // Restore user object if available
        if let userJson = YIKeychain.load(.userJson),
           let data = userJson.data(using: .utf8),
           let user = try? JSONDecoder().decode(YIUser.self, from: data) {
            self.currentUser = user
            logger.info("✅ Session restored: \(user.name)")
        } else {
            // Create minimal user object
            self.currentUser = YIUser(
                id: userId,
                token: token,
                tokenSecret: tokenSecret,
                name: "",
                email: ""
            )
            logger.info("✅ Session restored (minimal)")
        }
        
        return true
    }
    
    // MARK: - Private
    
    private func sendAgreementEvent(userId: String) async throws {
        let endpoint = AuthEndpoint.agreementEvent(
            userId: userId,
            phoneModel: "iPhone",
            appVersion: YIConfig.appVersion,
            country: YI.region.rawValue
        )
        
        _ = try await apiClient.request(
            endpoint: endpoint.path,
            method: endpoint.method,
            orderedParams: endpoint.orderedParams,
            needsAuth: true
        )
    }
}
