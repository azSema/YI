import Foundation

/// YI alert/event model from /v2/alert/list (motion detection events)
public struct YIAlert: Codable, Identifiable, Sendable, Equatable {
    
    /// Unique alert ID
    public let id: String
    
    /// Camera UID
    public let uid: String
    
    /// Event timestamp (milliseconds)
    public let time: Int64
    
    /// Alert type (0 = motion)
    public let type: Int
    
    /// Alert sub-type
    public let subType: Int
    
    /// Encrypted thumbnail URL
    public let picUrls: String?
    
    /// Decryption key for image (16 chars)
    public let picPwd: String?
    
    /// Encrypted video URL
    public let videoUrls: String?
    
    /// Decryption key for video (16 chars)
    public let videoPwd: String?
    
    /// Video file type (e.g., "mp4")
    public let fileType: String?
    
    /// URL expiration timestamp (milliseconds)
    public let expireTime: Int64?
    
    /// AI alert level
    public let aiAlertLevel: String?
    
    /// Media type
    public let mediaType: Int?
    
    // MARK: - Coding Keys
    
    enum CodingKeys: String, CodingKey {
        case id
        case uid
        case time
        case type
        case subType = "sub_type"
        case picUrls = "pic_urls"
        case picPwd = "pic_pwd"
        case videoUrls = "video_urls"
        case videoPwd = "video_pwd"
        case fileType = "file_type"
        case expireTime = "expire_time"
        case aiAlertLevel = "ai_alert_level"
        case mediaType = "media_type"
    }
    
    // MARK: - Computed Properties
    
    /// Event date
    public var date: Date {
        Date(timeIntervalSince1970: Double(time) / 1000)
    }
    
    /// URL expiration date
    public var expirationDate: Date? {
        guard let expireTime = expireTime else { return nil }
        return Date(timeIntervalSince1970: Double(expireTime) / 1000)
    }
    
    /// Is URL expired
    public var isExpired: Bool {
        guard let expirationDate = expirationDate else { return false }
        return expirationDate < Date()
    }
    
    /// Has image
    public var hasImage: Bool {
        picUrls != nil && picPwd != nil
    }
    
    /// Has video
    public var hasVideo: Bool {
        videoUrls != nil && videoPwd != nil
    }
    
    /// Image URL (before decryption)
    public var imageURL: URL? {
        guard let urlString = picUrls else { return nil }
        return URL(string: urlString)
    }
    
    /// Video URL (before decryption)
    public var videoURL: URL? {
        guard let urlString = videoUrls else { return nil }
        return URL(string: urlString)
    }
}

/// Alert type enumeration
public enum YIAlertType: Int, Sendable {
    case motion = 0
    case sound = 1
    case humanDetection = 2
    case unknown = -1
    
    public init(rawValue: Int) {
        switch rawValue {
        case 0: self = .motion
        case 1: self = .sound
        case 2: self = .humanDetection
        default: self = .unknown
        }
    }
}
