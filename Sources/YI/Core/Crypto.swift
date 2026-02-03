import Foundation
import CommonCrypto

/// Cryptographic utilities for YI API
public enum YICrypto {
    
    // MARK: - Password Encryption
    
    /// Encrypt password using HMAC-SHA256
    /// - Parameter password: Plain text password
    /// - Returns: Base64 encoded HMAC-SHA256 hash
    public static func encryptPassword(_ password: String) -> String {
        let key = YIConfig.passwordHMACKey
        guard let keyData = key.data(using: .utf8),
              let passwordData = password.data(using: .utf8) else {
            return ""
        }
        
        var hmac = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        keyData.withUnsafeBytes { keyBytes in
            passwordData.withUnsafeBytes { dataBytes in
                CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA256),
                       keyBytes.baseAddress, keyData.count,
                       dataBytes.baseAddress, passwordData.count,
                       &hmac)
            }
        }
        
        return Data(hmac).base64EncodedString()
    }
    
    // MARK: - Request Signing
    
    /// Sign request parameters using HMAC-SHA1
    /// - Parameters:
    ///   - params: Query string (param1=value1&param2=value2)
    ///   - token: Auth token
    ///   - tokenSecret: Auth token secret
    /// - Returns: Base64 encoded HMAC-SHA1 signature
    public static func signRequest(params: String, token: String, tokenSecret: String) -> String {
        let key = "\(token)&\(tokenSecret)"
        guard let keyData = key.data(using: .utf8),
              let paramsData = params.data(using: .utf8) else {
            return ""
        }
        
        var hmac = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        keyData.withUnsafeBytes { keyBytes in
            paramsData.withUnsafeBytes { dataBytes in
                CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA1),
                       keyBytes.baseAddress, keyData.count,
                       dataBytes.baseAddress, paramsData.count,
                       &hmac)
            }
        }
        
        return Data(hmac).base64EncodedString()
    }
    
    // MARK: - WiFi Password Encryption
    
    /// Encrypt WiFi password for QR code using XOR with fixed key
    /// - Parameter password: Plain WiFi password
    /// - Returns: Base64 encoded XOR'd password
    public static func encryptWiFiPassword(_ password: String) -> String {
        let passwordBytes = Array(password.utf8)
        let key = YIConfig.wifiPasswordXORKey
        
        var xorBytes = [UInt8]()
        for (i, byte) in passwordBytes.enumerated() {
            xorBytes.append(byte ^ key[i % key.count])
        }
        
        return Data(xorBytes).base64EncodedString()
    }
    
    // MARK: - Media Decryption
    
    /// Decrypt AES-128-ECB encrypted media (images/videos from alerts)
    /// - Parameters:
    ///   - data: Encrypted data (first 4 bytes = original size, rest = AES payload)
    ///   - password: 16-char decryption key (pic_pwd or video_pwd)
    /// - Returns: Decrypted data or nil if failed
    public static func decryptMedia(data: Data, password: String) -> Data? {
        guard data.count > 4 else { return nil }
        
        // First 4 bytes: original size (little-endian uint32)
        let originalSize = data.prefix(4).withUnsafeBytes { $0.load(as: UInt32.self) }
        let encryptedData = data.dropFirst(4)
        
        // Key is first 16 chars of password
        let keyString = String(password.prefix(16))
        guard let keyData = keyString.data(using: .utf8), keyData.count == 16 else {
            return nil
        }
        
        // AES-128-ECB decryption
        let bufferSize = encryptedData.count + kCCBlockSizeAES128
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        var numBytesDecrypted = 0
        
        let status = keyData.withUnsafeBytes { keyBytes in
            encryptedData.withUnsafeBytes { dataBytes in
                CCCrypt(
                    CCOperation(kCCDecrypt),
                    CCAlgorithm(kCCAlgorithmAES),
                    CCOptions(kCCOptionECBMode),
                    keyBytes.baseAddress, kCCKeySizeAES128,
                    nil, // no IV for ECB
                    dataBytes.baseAddress, encryptedData.count,
                    &buffer, bufferSize,
                    &numBytesDecrypted
                )
            }
        }
        
        guard status == kCCSuccess else { return nil }
        
        // Trim to original size
        let decrypted = Data(buffer.prefix(Int(originalSize)))
        return decrypted
    }
    
    // MARK: - URL Encoding
    
    /// URL encode a value with proper character escaping
    /// - Parameter value: Value to encode
    /// - Returns: URL encoded string
    public static func urlEncode(_ value: String) -> String {
        var encoded = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
        
        // Additional encoding for special characters
        for (char, replacement) in YIConfig.urlEncodingMap {
            encoded = encoded.replacingOccurrences(of: char, with: replacement)
        }
        
        return encoded
    }
}
