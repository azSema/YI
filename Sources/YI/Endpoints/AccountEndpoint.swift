import Foundation

/// Account/Profile API endpoints
public enum AccountEndpoint {
    
    /// Get user properties
    case properties(userId: String)
    
    /// Update extended info (timezone, language, location)
    case updateExtInfo(userId: String, timezone: String, language: String, location: String)
    
    /// Get login history
    case loginHistory(userId: String, startTime: Int, endTime: Int)
    
    // MARK: - Properties
    
    /// HTTP method
    public var method: String {
        switch self {
        case .properties, .loginHistory:
            return "GET"
        case .updateExtInfo:
            return "PUT"
        }
    }
    
    /// API path
    public var path: String {
        switch self {
        case .properties:
            return "/v4/users/prop"
        case .updateExtInfo:
            return "/v4/users/extinfo"
        case .loginHistory:
            return "/v5/users/loginInfos/search"
        }
    }
    
    /// Ordered parameters for HMAC signing
    public var orderedParams: [(String, String)] {
        switch self {
        case .properties(let userId):
            return [
                ("seq", "1"),
                ("userid", userId)
            ]
            
        case .updateExtInfo(let userId, let timezone, let language, let location):
            return [
                ("seq", "1"),
                ("userid", userId),
                ("timezone", YICrypto.urlEncode(timezone)),
                ("language", language),
                ("location", location)
            ]
            
        case .loginHistory(let userId, let startTime, let endTime):
            return [
                ("seq", "1"),
                ("userid", userId),
                ("search_phrase", ""),
                ("start_time", String(startTime)),
                ("end_time", String(endTime)),
                ("start", "0"),
                ("row_count", "10")
            ]
        }
    }
    
    /// Whether endpoint needs HMAC authentication
    public var needsAuth: Bool {
        true
    }
}
