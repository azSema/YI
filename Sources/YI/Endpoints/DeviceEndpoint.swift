import Foundation

/// Device management API endpoints
public enum DeviceEndpoint {
    
    /// Get list of user's devices
    case list(userId: String)
    
    /// Get device info
    case info(userId: String, uids: String)
    
    /// Get TNP info for P2P connection
    case tnpInfo(userId: String, uid: String)
    
    /// Get device password for P2P
    case password(uid: String)
    
    /// Edit device name
    case edit(userId: String, uid: String, name: String, token: String)
    
    /// Delete device
    case delete(userId: String, uid: String, token: String)
    
    /// Check scan bind status
    case scanBind(userId: String, did: String)
    
    /// Get bind key for QR generation
    case getBindKey(userId: String)
    
    /// Check bind key status (polling)
    case checkBindKey(bindkey: String)
    
    // MARK: - Properties
    
    /// HTTP method
    public var method: String {
        "GET"
    }
    
    /// API path
    public var path: String {
        switch self {
        case .list:
            return "/v5/devices/list"
        case .info:
            return "/v4/devices/get_deviceinfo"
        case .tnpInfo:
            return "/v4/tnp/device_info"
        case .password:
            return "/v2/devices/password"
        case .edit:
            return "/v2/devices/edit"
        case .delete:
            return "/v2/devices/del"
        case .scanBind:
            return "/v5/scan/bind"
        case .getBindKey:
            return "/v2/qrcode/get_bindkey"
        case .checkBindKey:
            return "/v2/qrcode/check_bindkey"
        }
    }
    
    /// Ordered parameters for HMAC signing
    public var orderedParams: [(String, String)] {
        let timestamp = String(format: "%.6f", Date().timeIntervalSince1970)
        
        switch self {
        case .list(let userId):
            return [
                ("seq", "1"),
                ("userid", userId)
            ]
            
        case .info(let userId, let uids):
            return [
                ("seq", "1"),
                ("userid", userId),
                ("uids", uids)
            ]
            
        case .tnpInfo(let userId, let uid):
            return [
                ("seq", "1"),
                ("userid", userId),
                ("uid", uid)
            ]
            
        case .password(let uid):
            return [
                ("seq", "1"),
                ("uid", uid)
            ]
            
        case .edit(let userId, let uid, let name, let token):
            return [
                ("seq", "1"),
                ("userid", userId),
                ("token", token),
                ("uid", uid),
                ("name", YICrypto.urlEncode(name)),
                ("message", "")
            ]
            
        case .delete(let userId, let uid, let token):
            return [
                ("seq", "1"),
                ("userid", userId),
                ("token", token),
                ("uid", uid)
            ]
            
        case .scanBind(let userId, let did):
            return [
                ("seq", "1"),
                ("userId", userId),
                ("did", did),
                ("timestamp", timestamp)
            ]
            
        case .getBindKey(let userId):
            return [
                ("seq", "1"),
                ("userid", userId),
                ("timestamp", timestamp)
            ]
            
        case .checkBindKey(let bindkey):
            return [
                ("seq", "1"),
                ("bindkey", bindkey),
                ("timestamp", timestamp)
            ]
        }
    }
    
    /// Whether endpoint needs HMAC authentication
    public var needsAuth: Bool {
        true
    }
}
