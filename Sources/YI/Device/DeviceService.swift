import Foundation
import os.log
import CoreImage.CIFilterBuiltins
#if canImport(UIKit)
import UIKit
#endif

private let logger = Logger(subsystem: "com.yi.YI", category: "DeviceService")

/// Device management service for YI cameras
///
/// Handles device listing, control, and pairing.
///
/// ## Usage
/// ```swift
/// // Get device list
/// let devices = try await YI.Device.list()
///
/// // Rename device
/// try await YI.Device.rename(uid: device.uid, name: "Living Room")
///
/// // Start pairing
/// let session = YI.Device.startPairing(did: "9FUSY218LLEKRL191010")
/// ```
public final class YIDeviceService: @unchecked Sendable {
    
    /// Shared instance
    public static let shared = YIDeviceService()
    
    private let apiClient = YIAPIClient.shared
    
    private init() {}
    
    // MARK: - List
    
    /// Get list of user's devices
    /// - Returns: Array of devices
    /// - Throws: YI.Error on failure
    public func list() async throws -> [YIDevice] {
        guard let userId = await apiClient.userId else {
            throw YI.Error.notAuthenticated
        }
        
        logger.info("📱 Fetching devices...")
        
        let endpoint = DeviceEndpoint.list(userId: userId)
        let response = try await apiClient.request(
            endpoint: endpoint.path,
            method: endpoint.method,
            orderedParams: endpoint.orderedParams,
            needsAuth: true
        )
        
        guard let data = response["data"] as? [[String: Any]] else {
            return []
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: data)
        let devices = try JSONDecoder().decode([YIDevice].self, from: jsonData)
        
        logger.info("✅ Found \(devices.count) devices")
        return devices
    }
    
    // MARK: - Info
    
    /// Get TNP info for P2P connection
    /// - Parameter uid: Device UID
    /// - Returns: TNP info with InitString
    /// - Throws: YI.Error on failure
    public func tnpInfo(uid: String) async throws -> YIDeviceTNPInfo {
        guard let userId = await apiClient.userId else {
            throw YI.Error.notAuthenticated
        }
        
        logger.info("📱 Getting TNP info: \(uid)")
        
        let endpoint = DeviceEndpoint.tnpInfo(userId: userId, uid: uid)
        let response = try await apiClient.request(
            endpoint: endpoint.path,
            method: endpoint.method,
            orderedParams: endpoint.orderedParams,
            needsAuth: true
        )
        
        guard let data = response["data"] as? [String: Any] else {
            throw YI.Error.deviceNotFound
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: data)
        return try JSONDecoder().decode(YIDeviceTNPInfo.self, from: jsonData)
    }
    
    // MARK: - Control
    
    /// Rename device
    /// - Parameters:
    ///   - uid: Device UID
    ///   - name: New name
    /// - Throws: YI.Error on failure
    public func rename(uid: String, name: String) async throws {
        guard let userId = await apiClient.userId,
              let token = await apiClient.token else {
            throw YI.Error.notAuthenticated
        }
        
        logger.info("📱 Renaming: \(uid) -> \(name)")
        
        let endpoint = DeviceEndpoint.edit(userId: userId, uid: uid, name: name, token: token)
        _ = try await apiClient.request(
            endpoint: endpoint.path,
            method: endpoint.method,
            orderedParams: endpoint.orderedParams,
            needsAuth: true
        )
        
        logger.info("✅ Renamed")
    }
    
    /// Delete device
    /// - Parameter uid: Device UID
    /// - Throws: YI.Error on failure
    public func delete(uid: String) async throws {
        guard let userId = await apiClient.userId,
              let token = await apiClient.token else {
            throw YI.Error.notAuthenticated
        }
        
        logger.info("📱 Deleting: \(uid)")
        
        let endpoint = DeviceEndpoint.delete(userId: userId, uid: uid, token: token)
        _ = try await apiClient.request(
            endpoint: endpoint.path,
            method: endpoint.method,
            orderedParams: endpoint.orderedParams,
            needsAuth: true
        )
        
        logger.info("✅ Deleted")
    }
    
    // MARK: - Pairing
    
    /// Start device pairing session
    /// - Parameter did: Device ID from QR code on camera
    /// - Returns: Pairing session
    public func startPairing(did: String) -> YIPairingSession {
        return YIPairingSession(did: did, apiClient: apiClient)
    }
}

// MARK: - Pairing Session

/// Device pairing session
///
/// Manages the multi-step pairing flow:
/// 1. Scan QR code on camera -> get DID
/// 2. Call checkScanBind (may return 57002, that's OK)
/// 3. Get bindkey from server
/// 4. Generate QR code with WiFi credentials
/// 5. Show QR to camera
/// 6. Poll checkBindKey until success
public final class YIPairingSession: @unchecked Sendable {
    
    /// Device ID from camera QR code
    public let did: String
    
    /// Current pairing state
    public private(set) var state: YIPairingState = .idle
    
    /// Bind key for QR generation
    public private(set) var bindkey: String?
    
    private let apiClient: YIAPIClient
    
    init(did: String, apiClient: YIAPIClient) {
        self.did = did
        self.apiClient = apiClient
    }
    
    /// Check if camera is ready (optional, may fail with 57002)
    public func checkScanBind() async throws {
        guard let userId = await apiClient.userId else {
            throw YI.Error.notAuthenticated
        }
        
        state = .scanning
        
        let endpoint = DeviceEndpoint.scanBind(userId: userId, did: did)
        
        // This may throw deviceNotInPairingMode - that's expected, continue anyway
        do {
            _ = try await apiClient.request(
                endpoint: endpoint.path,
                method: endpoint.method,
                orderedParams: endpoint.orderedParams,
                needsAuth: true
            )
        } catch YI.Error.deviceNotInPairingMode {
            // Expected - continue
        }
        
        state = .waitingForVoice
    }
    
    /// Get bind key from server
    /// - Returns: Bind key for QR generation
    public func getBindKey() async throws -> String {
        guard let userId = await apiClient.userId else {
            throw YI.Error.notAuthenticated
        }
        
        state = .enteringWiFi
        
        let endpoint = DeviceEndpoint.getBindKey(userId: userId)
        let response = try await apiClient.request(
            endpoint: endpoint.path,
            method: endpoint.method,
            orderedParams: endpoint.orderedParams,
            needsAuth: true
        )
        
        guard let data = response["data"] as? [String: Any],
              let key = data["bindkey"] as? String else {
            throw YI.Error.invalidResponse
        }
        
        self.bindkey = key
        state = .generatingQR(bindkey: key)
        
        return key
    }
    
    /// Generate QR code content for camera
    /// - Parameters:
    ///   - ssid: WiFi network name (2.4GHz only!)
    ///   - password: WiFi password
    /// - Returns: QR code content string
    public func generateQRContent(ssid: String, password: String) -> String? {
        guard let bindkey = bindkey else { return nil }
        
        let ssidBase64 = Data(ssid.utf8).base64EncodedString()
        let passwordEncrypted = YICrypto.encryptWiFiPassword(password)
        
        return "b=\(bindkey)&s=\(ssidBase64)&p=\(passwordEncrypted)"
    }
    
    #if canImport(UIKit)
    /// Generate QR code image for camera
    /// - Parameters:
    ///   - ssid: WiFi network name (2.4GHz only!)
    ///   - password: WiFi password
    /// - Returns: QR code UIImage
    public func generateQRImage(ssid: String, password: String) -> UIImage? {
        guard let content = generateQRContent(ssid: ssid, password: password),
              let data = content.data(using: .utf8) else {
            return nil
        }
        
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")
        
        guard let ciImage = filter.outputImage else { return nil }
        
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = ciImage.transformed(by: transform)
        
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
    #endif
    
    /// Wait for camera to connect (polling)
    /// - Parameter timeout: Timeout in seconds (default: 120)
    /// - Returns: Camera UID on success
    /// - Throws: YI.Error.pairingTimeout on timeout
    public func waitForConnection(timeout: TimeInterval = 120) async throws -> String {
        guard let bindkey = bindkey else {
            throw YI.Error.invalidResponse
        }
        
        state = .waitingForCamera
        
        let startTime = Date()
        let pollInterval: TimeInterval = 2
        
        while Date().timeIntervalSince(startTime) < timeout {
            let endpoint = DeviceEndpoint.checkBindKey(bindkey: bindkey)
            
            do {
                let response = try await apiClient.request(
                    endpoint: endpoint.path,
                    method: endpoint.method,
                    orderedParams: endpoint.orderedParams,
                    needsAuth: true
                )
                
                if let data = response["data"] as? [String: Any],
                   let ret = data["ret"] as? Int,
                   ret == 1,
                   let uid = data["uid"] as? String {
                    state = .success(uid: uid)
                    return uid
                }
            } catch {
                // Continue polling on error
            }
            
            try await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
        }
        
        state = .failed(YI.Error.pairingTimeout)
        throw YI.Error.pairingTimeout
    }
}
