import Foundation

/// YI camera device model from /v5/devices/list
public struct YIDevice: Codable, Identifiable, Sendable, Equatable {
    
    /// TUTK UID for P2P connection
    public let uid: String
    
    /// Device ID (from QR code on camera)
    public let did: String?
    
    /// Camera name
    public let name: String
    
    /// P2P authentication password (32-char hex)
    public let password: String
    
    /// Online status
    public let online: Bool
    
    /// Device state (0 = off, 1 = on)
    public let state: Int?
    
    /// Camera model ID
    public let model: String?
    
    /// Owner nickname
    public let nickname: String?
    
    /// Is shared device
    public let share: Bool?
    
    /// Has PIN code
    public let hasPincode: Bool?
    
    /// SD card state
    public let sdState: String?
    
    /// Firmware version
    public let interVersion: String?
    
    /// IPC parameters (network info)
    public let ipcParam: YIIPCParam?
    
    // MARK: - Identifiable
    
    public var id: String { uid }
    
    // MARK: - Computed
    
    /// Is camera turned on
    public var isOn: Bool {
        state == 1
    }
    
    /// Local IP address
    public var localIP: String? {
        ipcParam?.ip
    }
    
    /// WiFi network name
    public var wifiSSID: String? {
        ipcParam?.ssid
    }
    
    /// Signal quality (0-100)
    public var signalQuality: Int? {
        guard let quality = ipcParam?.signalQuality else { return nil }
        return Int(quality)
    }
}

/// IPC parameters - network info for device
public struct YIIPCParam: Codable, Sendable, Equatable {
    
    /// P2P encryption enabled
    public let p2pEncrypt: String?
    
    /// WiFi SSID
    public let ssid: String?
    
    /// MAC address
    public let mac: String?
    
    /// Local IP address
    public let ip: String?
    
    /// Signal quality (0-100 string)
    public let signalQuality: String?
    
    enum CodingKeys: String, CodingKey {
        case p2pEncrypt = "p2p_encrypt"
        case ssid
        case mac
        case ip
        case signalQuality = "signal_quality"
    }
}

/// TNP (ThroughTek) device info for P2P connection
public struct YIDeviceTNPInfo: Codable, Sendable, Equatable {
    
    /// Device ID (same as UID)
    public let did: String
    
    /// TUTK License prefix
    public let license: String
    
    /// P2P initialization string for TUTK SDK
    public let initString: String
    
    enum CodingKeys: String, CodingKey {
        case did = "DID"
        case license = "License"
        case initString = "InitString"
    }
}

/// Device pairing session state
public enum YIPairingState: Sendable {
    case idle
    case scanning
    case waitingForVoice
    case enteringWiFi
    case generatingQR(bindkey: String)
    case waitingForCamera
    case success(uid: String)
    case failed(YI.Error)
}
