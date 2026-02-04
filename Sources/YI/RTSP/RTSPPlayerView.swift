import SwiftUI

#if canImport(KSPlayer)
import KSPlayer

// MARK: - RTSP Player View

public struct RTSPPlayerView: View {
    let url: String
    @Binding var isPresented: Bool
    
    @State private var error: String?
    @State private var showGuide = false
    
    public init(url: String, isPresented: Binding<Bool>) {
        self.url = url
        self._isPresented = isPresented
    }
    
    public var body: some View {
        ZStack(alignment: .topTrailing) {
            if let error = error {
                errorView(error)
            } else {
                KSPlayerViewWrapper(url: url, onError: { err in
                    error = err
                })
                .ignoresSafeArea()
            }
            
            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding()
            }
        }
        .background(Color.black)
        .sheet(isPresented: $showGuide) {
            RTSPSetupGuideSheet()
        }
    }
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "video.slash")
                .font(.system(size: 60))
                .foregroundStyle(.gray)
            
            Text("Stream Unavailable")
                .font(.title2)
                .foregroundStyle(.white)
            
            Text(error)
                .font(.caption)
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button {
                showGuide = true
            } label: {
                Text("How to enable RTSP")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

// MARK: - KSPlayer Wrapper

struct KSPlayerViewWrapper: UIViewControllerRepresentable {
    let url: String
    let onError: (String) -> Void
    
    func makeUIViewController(context: Context) -> KSPlayerViewController {
        KSOptions.secondPlayerType = KSMEPlayer.self
        KSOptions.isAutoPlay = true
        
        let vc = KSPlayerViewController()
        vc.onError = onError
        if let streamURL = URL(string: url) {
            vc.playerView.set(url: streamURL, options: KSOptions())
        }
        return vc
    }
    
    func updateUIViewController(_ uiViewController: KSPlayerViewController, context: Context) {}
}

class KSPlayerViewController: UIViewController, PlayerControllerDelegate {
    let playerView = IOSVideoPlayerView()
    var onError: ((String) -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        view.addSubview(playerView)
        playerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            playerView.topAnchor.constraint(equalTo: view.topAnchor),
            playerView.leftAnchor.constraint(equalTo: view.leftAnchor),
            playerView.rightAnchor.constraint(equalTo: view.rightAnchor),
            playerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        playerView.delegate = self
        playerView.backBlock = { [weak self] in
            self?.dismiss(animated: true)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        playerView.pause()
    }
    
    // MARK: - PlayerControllerDelegate
    
    func playerController(state: KSPlayerState) {}
    func playerController(currentTime: TimeInterval, totalTime: TimeInterval) {}
    func playerController(bufferedCount: Int, consumeTime: TimeInterval) {}
    func playerController(seek: TimeInterval) {}
    func playerController(maskShow: Bool) {}
    func playerController(action: PlayerButtonType) {}
    
    func playerController(finish error: Error?) {
        if error != nil {
            DispatchQueue.main.async {
                self.onError?("RTSP stream not available.\nMake sure yi-hack is installed.")
            }
        }
    }
}

// MARK: - RTSP Setup Guide

public struct RTSPSetupGuideSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("RTSP stream is not available on this camera.")
                            .font(.headline)
                        
                        Text("To enable local streaming, you need to install yi-hack firmware. This works only on local network.")
                            .foregroundStyle(.secondary)
                    }
                    
                    Divider()
                    
                    // URL Structure
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Stream URL Format", systemImage: "link")
                            .font(.headline)
                        
                        Text("rtsp://{CAMERA_IP}/ch0_0.h264")
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        
                        Text("IP is shown in camera card or in Kami Home app: Camera Settings → Network Info")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Divider()
                    
                    // Requirements
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Requirements", systemImage: "checklist")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            requirementRow(icon: "sdcard", text: "microSD card (16 GB or less recommended)")
                            requirementRow(icon: "externaldrive", text: "Format as FAT32 (exFAT won't work!)")
                            requirementRow(icon: "wifi", text: "Phone and camera on same WiFi network")
                        }
                    }
                    
                    Divider()
                    
                    // Step 1 - Download
                    VStack(alignment: .leading, spacing: 8) {
                        Label("1. Download Firmware", systemImage: "arrow.down.circle.fill")
                            .font(.headline)
                        
                        Link(destination: URL(string: "https://github.com/alienatedsec/yi-hack-v5/releases")!) {
                            HStack {
                                Image(systemName: "link")
                                Text("github.com/alienatedsec/yi-hack-v5/releases")
                            }
                            .font(.system(.subheadline, design: .monospaced))
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            modelRow(model: "Yi 1080p Dome", files: "home_h20 + rootfs_h20")
                            modelRow(model: "Yi Home 1080p", files: "home_y20 + rootfs_y20")
                            modelRow(model: "Yi Outdoor", files: "home_h30 + rootfs_h30")
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    
                    // Step 2 - Copy
                    VStack(alignment: .leading, spacing: 8) {
                        Label("2. Copy to microSD", systemImage: "doc.on.doc.fill")
                            .font(.headline)
                        
                        Text("Copy to root of microSD card:")
                            .foregroundStyle(.secondary)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("• home_xx file")
                            Text("• rootfs_xx file")
                            Text("• yi-hack-v5 folder")
                        }
                        .font(.subheadline)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        
                        Text("Important: Verify filenames didn't change during copy!")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    
                    // Step 3 - Flash
                    VStack(alignment: .leading, spacing: 8) {
                        Label("3. Flash Camera", systemImage: "bolt.fill")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            flashStep(num: "1", text: "Power OFF camera (unplug)")
                            flashStep(num: "2", text: "Insert microSD card")
                            flashStep(num: "3", text: "Power ON camera (plug in)")
                            flashStep(num: "4", text: "Wait for yellow light ~30 sec")
                            flashStep(num: "5", text: "Camera reboots automatically")
                            flashStep(num: "6", text: "Yellow light again ~2 min")
                            flashStep(num: "7", text: "Blue light = Done!")
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    
                    // Step 4 - Verify
                    VStack(alignment: .leading, spacing: 8) {
                        Label("4. Verify Installation", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                        
                        Text("Open in browser:")
                            .foregroundStyle(.secondary)
                        
                        Text("http://CAMERA_IP")
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                    
                    Divider()
                    
                    // Troubleshooting
                    VStack(alignment: .leading, spacing: 8) {
                        Label("If Web Interface Doesn't Open", systemImage: "exclamationmark.triangle.fill")
                            .font(.headline)
                            .foregroundStyle(.orange)
                        
                        Text("Connect via SSH and enable RTSP manually:")
                            .foregroundStyle(.secondary)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("# SSH (empty password)")
                                .foregroundStyle(.secondary)
                            Text("ssh root@CAMERA_IP")
                            Text("")
                            Text("# Enable RTSP")
                                .foregroundStyle(.secondary)
                            Text("sed -i 's/RTSP=no/RTSP=yes/' \\")
                            Text("  /tmp/sd/yi-hack-v5/etc/system.conf")
                            Text("")
                            Text("# Start RTSP server")
                                .foregroundStyle(.secondary)
                            Text("/home/yi-hack-v5/script/wd_rtsp.sh &")
                        }
                        .font(.system(.caption, design: .monospaced))
                        .padding()
                        .background(Color(.black))
                        .foregroundStyle(.green)
                        .cornerRadius(8)
                    }
                    
                    Divider()
                    
                    // Limitations
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Limitations", systemImage: "info.circle.fill")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            limitationRow(text: "Works only on local WiFi network")
                            limitationRow(text: "Requires yi-hack firmware")
                            limitationRow(text: "Port forwarding unreliable for internet access")
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Setup RTSP Stream")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func requirementRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
        }
    }
    
    private func modelRow(model: String, files: String) -> some View {
        HStack {
            Text(model)
                .font(.subheadline)
            Spacer()
            Text(files)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
    
    private func flashStep(num: String, text: String) -> some View {
        HStack(spacing: 12) {
            Text(num)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(.blue))
            Text(text)
                .font(.subheadline)
        }
    }
    
    private func limitationRow(text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
                .font(.caption)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#endif

// MARK: - RTSP Helper (always available)

public enum YIRTSP {
    
    /// Build RTSP URL from camera IP
    /// - Parameter ip: Camera local IP address
    /// - Returns: Full RTSP URL string
    public static func buildURL(ip: String) -> String {
        return "rtsp://\(ip)/ch0_0.h264"
    }
    
    /// Check if RTSP port (554) is reachable
    /// - Parameters:
    ///   - ip: Camera IP address
    ///   - completion: Called with true if port is open
    public static func checkAvailability(ip: String, completion: @escaping (Bool) -> Void) {
        Task.detached {
            var readStream: Unmanaged<CFReadStream>?
            var writeStream: Unmanaged<CFWriteStream>?
            
            CFStreamCreatePairWithSocketToHost(nil, ip as CFString, 554, &readStream, &writeStream)
            
            guard let read = readStream?.takeRetainedValue() else {
                await MainActor.run { completion(false) }
                return
            }
            
            let success = CFReadStreamOpen(read)
            CFReadStreamClose(read)
            
            await MainActor.run { completion(success) }
        }
    }
}
