import Foundation
import os.log

private let logger = Logger(subsystem: "com.yi.YI", category: "APIClient")

/// HTTP client for YI API with HMAC signing
public actor YIAPIClient {
    
    /// Shared instance
    public static let shared = YIAPIClient()
    
    private let session: URLSession
    
    /// Current auth credentials (set after login)
    internal var token: String?
    internal var tokenSecret: String?
    internal var userId: String?
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Auth Management
    
    /// Set auth credentials after login
    func setCredentials(token: String, tokenSecret: String, userId: String) {
        self.token = token
        self.tokenSecret = tokenSecret
        self.userId = userId
    }
    
    /// Clear auth credentials on logout
    func clearCredentials() {
        self.token = nil
        self.tokenSecret = nil
        self.userId = nil
    }
    
    /// Check if authenticated
    var isAuthenticated: Bool {
        token != nil && tokenSecret != nil
    }
    
    // MARK: - Request
    
    /// Make API request with automatic HMAC signing
    /// - Parameters:
    ///   - endpoint: API endpoint path (e.g., "/v4/users/login")
    ///   - method: HTTP method (GET, POST, PUT)
    ///   - orderedParams: Parameters in specific order (important for HMAC!)
    ///   - needsAuth: Whether request needs HMAC signature
    ///   - body: Optional POST body
    /// - Returns: JSON response dictionary
    public func request(
        endpoint: String,
        method: String = "GET",
        orderedParams: [(String, String)],
        needsAuth: Bool = false,
        body: Data? = nil
    ) async throws -> [String: Any] {
        
        var params = orderedParams
        
        // Add HMAC if needed
        if needsAuth {
            guard let token = token, let tokenSecret = tokenSecret else {
                throw YI.Error.notAuthenticated
            }
            
            let queryString = params.map { "\($0.0)=\($0.1)" }.joined(separator: "&")
            let hmac = YICrypto.signRequest(params: queryString, token: token, tokenSecret: tokenSecret)
            let encodedHmac = YICrypto.urlEncode(hmac)
            params.append(("hmac", encodedHmac))
        }
        
        // Build URL
        let queryString = params.map { "\($0.0)=\($0.1)" }.joined(separator: "&")
        let urlString = "\(YI.region.baseURL)\(endpoint)?\(queryString)"
        
        guard let url = URL(string: urlString) else {
            throw YI.Error.invalidResponse
        }
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        // Add headers
        for (key, value) in YIConfig.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Add cookies if authenticated
        if let token = token, let tokenSecret = tokenSecret, let userId = userId {
            let cookie = "uidstr=\(userId); token=\(token); tokenSecret=\(tokenSecret)"
            request.setValue(cookie, forHTTPHeaderField: "Cookie")
        }
        
        // Add body for POST
        if let body = body {
            request.httpBody = body
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        }
        
        logger.debug("📤 \(method) \(endpoint)")
        
        // Execute request
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw YI.Error.invalidResponse
        }
        
        logger.debug("📥 \(httpResponse.statusCode) \(endpoint)")
        
        // Parse JSON
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw YI.Error.invalidResponse
        }
        
        // Check API response code
        let code = (json["code"] as? String) ?? String(describing: json["code"] ?? "")
        
        switch code {
        case "20000":
            return json
        case "20261":
            throw YI.Error.invalidCredentials
        case "40110":
            throw YI.Error.accountNotActivated
        case "20254":
            throw YI.Error.emailAlreadyRegistered
        case "57002":
            throw YI.Error.deviceNotInPairingMode
        default:
            let msg = json["msg"] as? String
            throw YI.Error.apiError(code: code, message: msg)
        }
    }
    
    // MARK: - Download
    
    /// Download data from URL
    /// - Parameter url: URL to download from
    /// - Returns: Downloaded data
    public func download(url: URL) async throws -> Data {
        let (data, _) = try await session.data(from: url)
        return data
    }
}
