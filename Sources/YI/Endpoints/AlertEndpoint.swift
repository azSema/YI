import Foundation

/// Alert/Events API endpoints
public enum AlertEndpoint {
    
    /// Get list of alerts (motion detection events)
    case list(userId: String, from: Int, to: Int, limit: Int)
    
    /// Get deleted alerts list
    case deletedList(userId: String, from: Int, to: Int, limit: Int)
    
    /// Get push notification properties
    case pushProperties(userId: String, uid: String, inviterUserId: String)
    
    /// Update push notification properties
    case updatePushProperties(
        userId: String,
        uid: String,
        pushFlag: Int,
        pushFlagVideo: Int,
        pushFlagAudio: Int,
        inviterUserId: String
    )
    
    // MARK: - Properties
    
    /// HTTP method
    public var method: String {
        switch self {
        case .list, .deletedList:
            return "GET"
        case .pushProperties:
            return "POST"
        case .updatePushProperties:
            return "PUT"
        }
    }
    
    /// API path
    public var path: String {
        switch self {
        case .list:
            return "/v2/alert/list"
        case .deletedList:
            return "/v5/alert/del_list"
        case .pushProperties:
            return "/v2/alert/get_push"
        case .updatePushProperties:
            return "/v5/alert/push_prop"
        }
    }
    
    /// Ordered parameters for HMAC signing
    public var orderedParams: [(String, String)] {
        switch self {
        case .list(let userId, let from, let to, let limit):
            return [
                ("seq", "1"),
                ("userid", userId),
                ("type", ""),
                ("sub_type", ""),
                ("from", String(from)),
                ("to", String(to)),
                ("limit", String(limit)),
                ("fromDB", "True"),
                ("expires", "1440")
            ]
            
        case .deletedList(let userId, let from, let to, let limit):
            return [
                ("seq", "1"),
                ("userid", userId),
                ("from", String(from)),
                ("to", String(to)),
                ("limit", String(limit))
            ]
            
        case .pushProperties(let userId, let uid, let inviterUserId):
            return [
                ("seq", "1"),
                ("uid", uid),
                ("userid", userId),
                ("inviterUserId", inviterUserId)
            ]
            
        case .updatePushProperties(let userId, let uid, let pushFlag, let pushFlagVideo, let pushFlagAudio, let inviterUserId):
            return [
                ("seq", "1"),
                ("userid", userId),
                ("uid", uid),
                ("pushflag", String(pushFlag)),
                ("pushflagvideo", String(pushFlagVideo)),
                ("pushflagaudio", String(pushFlagAudio)),
                ("uploadflag", "0"),
                ("inviterUserId", inviterUserId)
            ]
        }
    }
    
    /// Whether endpoint needs HMAC authentication
    public var needsAuth: Bool {
        true
    }
}
