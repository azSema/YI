import Foundation

/// Authentication API endpoints
public enum AuthEndpoint {
    
    /// Check user region before login
    case queryRegion(account: String, country: String)
    
    /// Login with email and password
    case login(
        account: String,
        password: String,
        deviceName: String,
        deviceType: String,
        osVersion: String
    )
    
    /// Register new account
    case register(
        name: String,
        firstName: String,
        lastName: String,
        account: String,
        password: String,
        mobile: String?,
        mobileRegion: String?,
        language: String,
        country: String
    )
    
    /// Resend activation email
    case resendActivation(email: String, password: String)
    
    /// Agreement event (after login)
    case agreementEvent(
        userId: String,
        phoneModel: String,
        appVersion: String,
        country: String
    )
    
    // MARK: - Properties
    
    /// HTTP method
    public var method: String {
        switch self {
        case .queryRegion, .login, .resendActivation:
            return "GET"
        case .register:
            return "PUT"
        case .agreementEvent:
            return "POST"
        }
    }
    
    /// API path
    public var path: String {
        switch self {
        case .queryRegion:
            return "/v5/query/user/region"
        case .login:
            return "/v4/users/login"
        case .register:
            return "/v4/users/register"
        case .resendActivation:
            return "/v4/users/resend_activation_code"
        case .agreementEvent:
            return "/v5/agreement/event"
        }
    }
    
    /// Ordered parameters for HMAC signing
    public var orderedParams: [(String, String)] {
        switch self {
        case .queryRegion(let account, let country):
            return [
                ("seq", "1"),
                ("account", YICrypto.urlEncode(account)),
                ("country", country)
            ]
            
        case .login(let account, let password, let deviceName, let deviceType, let osVersion):
            let encryptedPassword = YICrypto.encryptPassword(password)
            return [
                ("seq", "1"),
                ("account", YICrypto.urlEncode(account)),
                ("email", ""),
                ("mobile", ""),
                ("password", YICrypto.urlEncode(encryptedPassword)),
                ("dev_id", ""),
                ("dev_name", deviceName),
                ("dev_type", deviceType),
                ("dev_os_version", osVersion)
            ]
            
        case .register(let name, let firstName, let lastName, let account, let password, let mobile, let mobileRegion, let language, let country):
            let encryptedPassword = YICrypto.encryptPassword(password)
            let timestamp = String(Int(Date().timeIntervalSince1970 * 1000))
            return [
                ("seq", "1"),
                ("name", YICrypto.urlEncode(name)),
                ("first_name", YICrypto.urlEncode(firstName)),
                ("last_name", YICrypto.urlEncode(lastName)),
                ("account", YICrypto.urlEncode(account)),
                ("password", YICrypto.urlEncode(encryptedPassword)),
                ("mobile", mobile ?? ""),
                ("user_mobile_region", YICrypto.urlEncode(mobileRegion ?? "")),
                ("img", ""),
                ("language", language),
                ("log_time", timestamp),
                ("country", country),
                ("agreement_version", "1.1"),
                ("phone_model", "iPhone"),
                ("app_version", YIConfig.appVersion),
                ("client_code_flag", "1")
            ]
            
        case .resendActivation(let email, let password):
            let encryptedPassword = YICrypto.encryptPassword(password)
            return [
                ("seq", "1"),
                ("email", YICrypto.urlEncode(email)),
                ("password", YICrypto.urlEncode(encryptedPassword))
            ]
            
        case .agreementEvent(let userId, let phoneModel, let appVersion, let country):
            let timestamp = String(Int(Date().timeIntervalSince1970 * 1000))
            return [
                ("seq", "1"),
                ("userid", userId),
                ("agreement_version", "1.1"),
                ("app_version", appVersion),
                ("country", country),
                ("phone_model", phoneModel),
                ("log_time", timestamp),
                ("type", "1")
            ]
        }
    }
    
    /// Whether endpoint needs HMAC authentication
    public var needsAuth: Bool {
        switch self {
        case .queryRegion, .login, .register, .resendActivation:
            return false
        case .agreementEvent:
            return true
        }
    }
}
