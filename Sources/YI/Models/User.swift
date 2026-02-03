import Foundation

/// YI user model from login response
public struct YIUser: Codable, Identifiable, Sendable, Equatable {
    
    /// User ID (numeric string)
    public let id: String
    
    /// Account email
    public let account: String
    
    /// Display name
    public let name: String
    
    /// First name
    public let firstName: String?
    
    /// Last name
    public let lastName: String?
    
    /// Auth token for API requests
    public let token: String
    
    /// Auth token secret for HMAC signing
    public let tokenSecret: String
    
    /// OpenID identifier
    public let openId: String?
    
    /// Phone number (without country code)
    public let mobile: String?
    
    /// Email address
    public let email: String?
    
    /// Avatar image URL
    public let img: String?
    
    /// Birthday string
    public let birthday: String?
    
    /// Registration timestamp (milliseconds)
    public let registerTime: String?
    
    // MARK: - Coding Keys
    
    enum CodingKeys: String, CodingKey {
        case id = "userid"
        case account
        case name
        case firstName = "first_name"
        case lastName = "last_name"
        case token
        case tokenSecret = "token_secret"
        case openId
        case mobile
        case email
        case img
        case birthday
        case registerTime = "register_time"
    }
    
    // MARK: - Computed Properties
    
    /// Full name from first + last name
    public var fullName: String {
        [firstName, lastName].compactMap { $0 }.joined(separator: " ")
    }
    
    /// Registration date parsed from timestamp
    public var registrationDate: Date? {
        guard let timeString = registerTime,
              let timestamp = Double(timeString) else { return nil }
        return Date(timeIntervalSince1970: timestamp / 1000)
    }
}

// MARK: - Init

extension YIUser {
    public init(
        id: String,
        token: String,
        tokenSecret: String,
        account: String = "",
        name: String = "",
        firstName: String? = nil,
        lastName: String? = nil,
        openId: String? = nil,
        mobile: String? = nil,
        email: String? = nil,
        img: String? = nil,
        birthday: String? = nil,
        registerTime: String? = nil
    ) {
        self.id = id
        self.token = token
        self.tokenSecret = tokenSecret
        self.account = account
        self.name = name
        self.firstName = firstName
        self.lastName = lastName
        self.openId = openId
        self.mobile = mobile
        self.email = email
        self.img = img
        self.birthday = birthday
        self.registerTime = registerTime
    }
}

// MARK: - Custom Decoding

extension YIUser {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // userid can be Int or String
        if let intId = try? container.decode(Int.self, forKey: .id) {
            self.id = String(intId)
        } else {
            self.id = try container.decode(String.self, forKey: .id)
        }
        
        self.account = try container.decode(String.self, forKey: .account)
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.firstName = try container.decodeIfPresent(String.self, forKey: .firstName)
        self.lastName = try container.decodeIfPresent(String.self, forKey: .lastName)
        self.token = try container.decode(String.self, forKey: .token)
        self.tokenSecret = try container.decode(String.self, forKey: .tokenSecret)
        self.openId = try container.decodeIfPresent(String.self, forKey: .openId)
        self.mobile = try container.decodeIfPresent(String.self, forKey: .mobile)
        self.email = try container.decodeIfPresent(String.self, forKey: .email)
        self.img = try container.decodeIfPresent(String.self, forKey: .img)
        self.birthday = try container.decodeIfPresent(String.self, forKey: .birthday)
        self.registerTime = try container.decodeIfPresent(String.self, forKey: .registerTime)
    }
}
