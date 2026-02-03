import Foundation

/// Configuration constants for YI API
public enum YIConfig {
    
    /// HMAC key for password encryption (HMAC-SHA256)
    static let passwordHMACKey = "KXLiUdAsO81ycDyEJAeETC$KklXdz3AC"
    
    /// XOR key for WiFi password encryption in QR codes
    static let wifiPasswordXORKey: [UInt8] = [0x00, 0x39, 0x4A, 0x46, 0x53, 0x6A, 0x6F, 0x38]
    
    /// App version for headers
    public static var appVersion = "4.8.5"
    
    /// App type
    public static var appType = "IOS"
    
    /// Country code
    public static var countryCode = "US"
    
    /// Common HTTP headers for all requests
    static var headers: [String: String] {
        [
            "x-xiaoyi-appVersion": "ios_kami;\(appVersion);\(appVersion)",
            "x-xiaoyi-appCountryCode": countryCode,
            "x-kamihome-appType": appType,
            "User-Agent": "KamiHome/\(appVersion) (iPhone; iOS 18.0; Scale/3.00)",
            "Accept": "*/*"
        ]
    }
    
    /// Characters that must be URL encoded in query values
    static let urlEncodingMap: [(String, String)] = [
        ("+", "%2B"),
        ("=", "%3D"),
        ("@", "%40"),
        ("/", "%2F")
    ]
}
