# YI - Swift Library for Yi/Kami Camera API

Swift library for interacting with Yi/Kami camera cloud API. Supports authentication, device management, pairing, and alert/event handling.

## Table of Contents

- [Features](#features)
- [Installation](#installation)
- [Quick Start](#quick-start)
  - [Initialization](#initialization-app-launch)
  - [Configuration](#configuration)
  - [Authentication](#authentication)
  - [Session Persistence](#session-persistence)
  - [Registration](#registration)
- [Device Management](#device-management)
- [Device Pairing](#device-pairing-full-ui-flow)
- [Alerts (Motion Detection)](#alerts-motion-detection)
- [Account](#account)
- [API Reference](#api-reference)
- [Error Handling](#error-handling)
- [Important Notes](#important-notes)
- [Requirements](#requirements)
- [License](#license)

## Features

- **Authentication**: Login, registration, session management
- **Device Management**: List cameras, control state, rename, delete
- **Device Pairing**: Full QR-code based pairing flow
- **Alerts**: Motion detection events with encrypted media download
- **Media Decryption**: AES-128-ECB decryption for images/videos

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/azSema/YI.git", from: "1.0.0")
]
```

### Manual

Copy the `YI/Sources/YI` folder into your Xcode project.

## Quick Start

### Initialization (App Launch)

```swift
import YI

@main
struct MyApp: App {
    init() {
        // Initialize YI - restores session from Keychain if available
        Task {
            let wasLoggedIn = await YI.initialize()
            if wasLoggedIn {
                print("Session restored from Keychain")
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### Configuration

```swift
// Configure region (default: .us)
YI.configure(region: .us)  // .us, .eu, or .cn
```

### Authentication

```swift
// Check if already logged in (restored from Keychain)
if YI.Auth.isLoggedIn {
    print("Already logged in as: \(YI.Auth.currentUser?.name ?? "")")
} else {
    // Login (credentials saved to Keychain automatically)
    do {
        let user = try await YI.Auth.login(
            email: "user@example.com",
            password: "password"
        )
        print("Logged in as: \(user.name)")
    } catch YI.Error.invalidCredentials {
        print("Wrong email or password")
    } catch YI.Error.accountNotActivated {
        print("Check email for activation link")
    }
}

// Logout (clears Keychain)
YI.Auth.logout()
```

### Session Persistence

YI automatically stores credentials in iOS Keychain:
- **On login**: token, tokenSecret, userId saved to Keychain
- **On `YI.initialize()`**: restores session from Keychain
- **On logout**: clears all Keychain data

No manual token management needed!
```

### Registration

**Password requirements:** min 8 characters, one uppercase letter, one digit.

```swift
try await YI.Auth.register(
    email: "user@example.com",
    password: "Password1",
    firstName: "John",
    lastName: "Doe"
)
// Check email for activation link
```

### Device Management

```swift
// Get all cameras
let devices = try await YI.Device.list()

for device in devices {
    print("\(device.name) - \(device.online ? "Online" : "Offline")")
    print("  UID: \(device.uid)")
    print("  IP: \(device.localIP ?? "N/A")")
}

// Rename camera
try await YI.Device.rename(uid: device.uid, name: "Living Room")

// Delete camera
try await YI.Device.delete(uid: device.uid)
```

### Device Pairing (Full UI Flow)

Pairing requires multiple UI screens. Here's the complete flow:

#### Step 1: Open QR Scanner
```swift
// Use AVFoundation to scan QR code on camera body (usually on bottom)
// QR contains: "did=9FUSY218LLEKRL191010" or just the DID string
import AVFoundation

// In your QR scanner delegate:
func metadataOutput(_ output: AVCaptureMetadataOutput, 
                    didOutput metadataObjects: [AVMetadataObject], 
                    from connection: AVCaptureConnection) {
    guard let qrCode = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
          let value = qrCode.stringValue else { return }
    
    // Extract DID from QR
    let did: String
    if value.contains("did=") {
        did = value.components(separatedBy: "did=").last ?? value
    } else {
        did = value  // QR contains just the DID
    }
    
    // Proceed to step 2
    showResetInstructions(did: did)
}
```

#### Step 2: Show "Reset Camera" Instructions
```swift
// UI: Show instructions to user
// - "Press and hold RESET button on camera for 5 seconds"
// - "Wait for LED to blink yellow/orange"
// - "Wait for voice: 'Waiting for connection'"
// - Button: "I heard 'Waiting for connection'" → proceed to step 3
```

#### Step 3: Enter WiFi Credentials
```swift
// UI: WiFi input form
// ⚠️ IMPORTANT: Show warning "Only 2.4GHz networks supported! 5GHz will NOT work"
// - TextField: SSID (network name)
// - SecureField: Password
// - Button: "Connect" → proceed to step 4
```

#### Step 4: Generate & Show QR to Camera
```swift
let session = YI.Device.startPairing(did: did)

// Optional: check scan bind (may fail with 57002 - that's OK)
try? await session.checkScanBind()

// Get bind key from server
let bindkey = try await session.getBindKey()

// Generate QR code image
guard let qrImage = session.generateQRImage(ssid: ssid, password: password) else {
    // Handle error
    return
}

// UI: Show QR code full screen
// - Display qrImage large and centered
// - Text: "Point camera at this QR code"
// - Text: "Keep phone steady until you hear 'Connection successful'"
// - Auto-start polling (step 5)
```

#### Step 5: Wait for Camera (Polling)
```swift
// Start polling in background while showing QR
Task {
    do {
        let uid = try await session.waitForConnection(timeout: 120)
        // Success! Camera is paired
        showSuccess(uid: uid)
    } catch YI.Error.pairingTimeout {
        showError("Camera didn't connect. Please try again.")
    }
}

// UI states during polling:
// - "Waiting for camera..." with spinner
// - On success: "Camera connected!" → go to device list
// - On timeout: "Connection failed" → offer retry
```

#### Complete Example (SwiftUI)
```swift
enum PairingStep {
    case scanQR
    case resetCamera(did: String)
    case enterWiFi(did: String)
    case showQR(did: String, ssid: String, password: String)
    case success(uid: String)
    case failed(Error)
}

struct AddCameraView: View {
    @State private var step: PairingStep = .scanQR
    @State private var session: YIPairingSession?
    
    var body: some View {
        switch step {
        case .scanQR:
            QRScannerView { did in
                step = .resetCamera(did: did)
            }
        case .resetCamera(let did):
            ResetInstructionsView {
                step = .enterWiFi(did: did)
            }
        case .enterWiFi(let did):
            WiFiInputView { ssid, password in
                step = .showQR(did: did, ssid: ssid, password: password)
                startPairing(did: did, ssid: ssid, password: password)
            }
        case .showQR(_, _, _):
            QRDisplayView(session: session)
        case .success(let uid):
            SuccessView(uid: uid)
        case .failed(let error):
            ErrorView(error: error) { step = .scanQR }
        }
    }
    
    func startPairing(did: String, ssid: String, password: String) {
        Task {
            session = YI.Device.startPairing(did: did)
            try? await session?.checkScanBind()
            _ = try await session?.getBindKey()
            
            let uid = try await session?.waitForConnection(timeout: 120)
            step = .success(uid: uid ?? "")
        }
    }
}
```

### Alerts (Motion Detection)

```swift
// Get alerts from last 7 days
let alerts = try await YI.Alerts.list(days: 7, limit: 50)

for alert in alerts {
    print("Alert at \(alert.date)")
    print("  Camera: \(alert.uid)")
    print("  Has image: \(alert.hasImage)")
    print("  Has video: \(alert.hasVideo)")
}

// Download and decrypt image
if let imageData = try await YI.Alerts.downloadImage(alert: alert) {
    let image = UIImage(data: imageData)
}

// Download and decrypt video
if let videoData = try await YI.Alerts.downloadVideo(alert: alert) {
    // Save to file or play
}
```

### Account

```swift
// Get user properties
let props = try await YI.Account.properties()

// Update timezone/language
try await YI.Account.updateExtInfo(
    timezone: "Europe/London",
    language: "en-US"
)

// Get login history
let history = try await YI.Account.loginHistory(days: 30)
```

## API Reference

### YI (Main Entry Point)

| Property/Method | Description |
|----------------|-------------|
| `YI.configure(region:)` | Set API region (.us, .eu, .cn) |
| `YI.Auth` | Authentication service |
| `YI.Device` | Device management service |
| `YI.Account` | Account/profile service |
| `YI.Alerts` | Alerts service |

### YI.Auth (YIAuthService)

| Method | Description |
|--------|-------------|
| `login(email:password:)` | Login and get user |
| `register(...)` | Register new account |
| `resendActivation(email:password:)` | Resend activation email |
| `logout()` | Logout current user |
| `isLoggedIn` | Check if logged in |
| `currentUser` | Current user or nil |

### YI.Device (YIDeviceService)

| Method | Description |
|--------|-------------|
| `list()` | Get all devices |
| `tnpInfo(uid:)` | Get P2P connection info |
| `rename(uid:name:)` | Rename device |
| `delete(uid:)` | Delete device |
| `startPairing(did:)` | Start pairing session |

### YI.Alerts (YIAlertService)

| Method | Description |
|--------|-------------|
| `list(days:limit:)` | Get alerts |
| `downloadImage(alert:)` | Download decrypted image |
| `downloadVideo(alert:)` | Download decrypted video |
| `pushSettings(uid:)` | Get push settings |
| `updatePushSettings(...)` | Update push settings |

### YI.Account (YIAccountService)

| Method | Description |
|--------|-------------|
| `properties()` | Get user properties |
| `updateExtInfo(...)` | Update timezone/language |
| `loginHistory(days:)` | Get login history |

## Error Handling

```swift
do {
    let user = try await YI.Auth.login(email: email, password: password)
} catch YI.Error.invalidCredentials {
    // Wrong email or password
} catch YI.Error.invalidPassword {
    // Password doesn't meet requirements (8+ chars, uppercase, digit)
} catch YI.Error.accountNotActivated {
    // Need to activate via email
} catch YI.Error.notAuthenticated {
    // Need to login first
} catch YI.Error.deviceNotFound {
    // Device doesn't exist
} catch YI.Error.pairingTimeout {
    // Pairing took too long
} catch YI.Error.apiError(let code, let message) {
    // API error with code
} catch {
    // Other error
}
```

## Important Notes

### WiFi Pairing
- **Only 2.4GHz WiFi networks are supported!** 5GHz will not work.
- Camera must be in pairing mode (yellow/orange LED blinking)
- Wait for "Waiting for connection" voice before showing QR

### Media Decryption
- Alert images/videos are AES-128-ECB encrypted
- Use `downloadImage`/`downloadVideo` methods for automatic decryption
- URLs expire after ~24 hours

### Regions
- US: `https://gw-us.xiaoyi.com`
- EU: `https://gw-eu.xiaoyi.com`
- CN: `https://gw.xiaoyi.com`

## Requirements

- iOS 15.0+ / macOS 12.0+
- Swift 5.5+
- Xcode 13.0+

### For RTSP Streaming (Required)

RTSP streaming requires KSPlayer. Add to your `Podfile`:

```ruby
pod 'KSPlayer', :git => 'https://github.com/kingslay/KSPlayer.git', :branch => 'main'
pod 'DisplayCriteria', :git => 'https://github.com/kingslay/KSPlayer.git', :branch => 'main'
pod 'FFmpegKit', :git => 'https://github.com/kingslay/FFmpegKit.git', :branch => 'main'
pod 'Libass', :git => 'https://github.com/kingslay/FFmpegKit.git', :branch => 'main'
```

Then run:
```bash
pod install
```

**Important:** Open `.xcworkspace` (not `.xcodeproj`) after installing pods.

---

## RTSP Local Streaming

RTSP allows direct video streaming from camera over local network (no cloud).

### How RTSP URL is Built

```
rtsp://{IP}/ch0_0.h264
```

| Part | Description | Example |
|------|-------------|---------|
| `rtsp://` | Protocol | - |
| `{IP}` | Camera local IP from `device.localIP` | `192.168.1.80` |
| `/ch0_0.h264` | Stream path (fixed for yi-hack) | - |

**Full example:** `rtsp://192.168.1.80/ch0_0.h264`

### Where IP Comes From

IP is returned from `YI.Device.list()` in `localIP` property:

```swift
let devices = try await YI.Device.list()
for device in devices {
    if let ip = device.localIP {
        let rtspURL = "rtsp://\(ip)/ch0_0.h264"
    }
}
```

### Using RTSPPlayerView

```swift
import YI

// Check if RTSP available
if let ip = device.localIP {
    let url = "rtsp://\(ip)/ch0_0.h264"
    
    // Show player
    RTSPPlayerView(url: url, isPresented: $showPlayer)
}
```

### Limitations

- **Local network only** - phone and camera must be on same WiFi
- **Requires yi-hack** - standard Yi firmware doesn't support RTSP
- **Port forwarding doesn't work** - RTSP over internet is unreliable

---

## yi-hack Installation Guide

yi-hack is custom firmware that enables RTSP streaming on Yi cameras.

### Requirements

- microSD card (16 GB or less recommended)
- Card **must be formatted as FAT32** (exFAT won't work)
- For cards > 32GB, force format to FAT32

### Installation Steps

1. **Download firmware** for your camera model:
   https://github.com/alienatedsec/yi-hack-v5/releases

   | Model | Files |
   |-------|-------|
   | Yi 1080p Dome | `home_h20` + `rootfs_h20` |
   | Yi Home 1080p | `home_y20` + `rootfs_y20` |
   | Yi Outdoor | `home_h30` + `rootfs_h30` |

2. **Copy to microSD card root:**
   - `home_xx`
   - `rootfs_xx`
   - `yi-hack-v5` folder

   **Important:** Verify filenames didn't change during copy!

3. **Power off camera** (unplug power)

4. **Insert microSD card** into camera

5. **Power on camera** (plug in power)

6. **Wait for flashing:**
   - Yellow light ~30 sec → firmware loading
   - Camera reboots
   - Yellow light ~2 min → final stage
   - Blue light → WiFi connected, done!

7. **Open web interface** in browser:
   ```
   http://CAMERA_IP
   ```
   
   Find IP in Kami Home app: Camera Settings → Network Info → IP Address

### If Web Interface Doesn't Open

```bash
# Check connectivity
ping 192.168.1.XX
nc -zv 192.168.1.XX 22   # SSH
nc -zv 192.168.1.XX 554  # RTSP

# SSH into camera (empty password)
ssh root@192.168.1.XX

# Enable RTSP
sed -i 's/RTSP=no/RTSP=yes/' /tmp/sd/yi-hack-v5/etc/system.conf

# Start RTSP server
/home/yi-hack-v5/script/wd_rtsp.sh &
```


## License

MIT License
