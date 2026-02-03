import Foundation
import os.log

private let logger = Logger(subsystem: "com.yi.YI", category: "AlertService")

/// Alert/Events service for motion detection
///
/// Handles alert listing and media download with decryption.
///
/// ## Usage
/// ```swift
/// // Get alerts
/// let alerts = try await YI.Alerts.list(days: 7)
///
/// // Download media
/// if let imageData = try await YI.Alerts.downloadImage(alert: alert) {
///     let image = UIImage(data: imageData)
/// }
/// ```
public final class YIAlertService: @unchecked Sendable {
    
    /// Shared instance
    public static let shared = YIAlertService()
    
    private let apiClient = YIAPIClient.shared
    
    private init() {}
    
    // MARK: - List
    
    /// Get list of alerts (motion detection events)
    /// - Parameters:
    ///   - days: Number of days to look back (default: 30)
    ///   - limit: Maximum number of alerts (default: 100)
    /// - Returns: Array of alerts
    /// - Throws: YI.Error on failure
    public func list(days: Int = 30, limit: Int = 100) async throws -> [YIAlert] {
        guard let userId = await apiClient.userId else {
            throw YI.Error.notAuthenticated
        }
        
        logger.info("🔔 Fetching alerts...")
        
        let now = Int(Date().timeIntervalSince1970)
        let from = now - (days * 24 * 60 * 60)
        
        let endpoint = AlertEndpoint.list(userId: userId, from: from, to: now, limit: limit)
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
        let alerts = try JSONDecoder().decode([YIAlert].self, from: jsonData)
        
        logger.info("✅ Found \(alerts.count) alerts")
        return alerts
    }
    
    // MARK: - Media Download
    
    /// Download and decrypt alert image
    /// - Parameter alert: Alert with image URL
    /// - Returns: Decrypted JPEG data or nil
    /// - Throws: YI.Error on failure
    public func downloadImage(alert: YIAlert) async throws -> Data? {
        guard let url = alert.imageURL,
              let password = alert.picPwd else {
            return nil
        }
        
        logger.info("📷 Downloading image: \(alert.id)")
        
        let encryptedData = try await apiClient.download(url: url)
        
        guard let decrypted = YICrypto.decryptMedia(data: encryptedData, password: password) else {
            throw YI.Error.decryptionFailed
        }
        
        logger.info("✅ Image decrypted: \(decrypted.count) bytes")
        return decrypted
    }
    
    /// Download and decrypt alert video
    /// - Parameter alert: Alert with video URL
    /// - Returns: Decrypted MP4 data or nil
    /// - Throws: YI.Error on failure
    public func downloadVideo(alert: YIAlert) async throws -> Data? {
        guard let url = alert.videoURL,
              let password = alert.videoPwd else {
            return nil
        }
        
        logger.info("🎬 Downloading video: \(alert.id)")
        
        let encryptedData = try await apiClient.download(url: url)
        
        guard let decrypted = YICrypto.decryptMedia(data: encryptedData, password: password) else {
            throw YI.Error.decryptionFailed
        }
        
        logger.info("✅ Video decrypted: \(decrypted.count) bytes")
        return decrypted
    }
    
    // MARK: - Push Settings
    
    /// Get push notification settings for device
    /// - Parameter uid: Device UID
    /// - Returns: Push settings dictionary
    /// - Throws: YI.Error on failure
    public func pushSettings(uid: String) async throws -> [String: Any] {
        guard let userId = await apiClient.userId else {
            throw YI.Error.notAuthenticated
        }
        
        let endpoint = AlertEndpoint.pushProperties(userId: userId, uid: uid, inviterUserId: userId)
        let response = try await apiClient.request(
            endpoint: endpoint.path,
            method: endpoint.method,
            orderedParams: endpoint.orderedParams,
            needsAuth: true
        )
        
        return response["data"] as? [String: Any] ?? [:]
    }
    
    /// Update push notification settings
    /// - Parameters:
    ///   - uid: Device UID
    ///   - enabled: Enable push notifications
    ///   - videoEnabled: Enable video in notifications
    ///   - audioEnabled: Enable audio alerts
    /// - Throws: YI.Error on failure
    public func updatePushSettings(
        uid: String,
        enabled: Bool,
        videoEnabled: Bool = true,
        audioEnabled: Bool = false
    ) async throws {
        guard let userId = await apiClient.userId else {
            throw YI.Error.notAuthenticated
        }
        
        let endpoint = AlertEndpoint.updatePushProperties(
            userId: userId,
            uid: uid,
            pushFlag: enabled ? 1 : 0,
            pushFlagVideo: videoEnabled ? 1 : 0,
            pushFlagAudio: audioEnabled ? 1 : 0,
            inviterUserId: userId
        )
        
        _ = try await apiClient.request(
            endpoint: endpoint.path,
            method: endpoint.method,
            orderedParams: endpoint.orderedParams,
            needsAuth: true
        )
    }
}
