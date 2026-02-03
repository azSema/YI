# ``YI``

Swift library for Yi/Kami camera cloud API.

## Overview

YI provides a clean, async/await API for interacting with Yi/Kami cameras. It supports authentication, device management, pairing, and alert handling.

### Quick Start

```swift
import YI

// Configure region
YI.configure(region: .us)

// Login
let user = try await YI.Auth.login(email: "user@example.com", password: "password")

// Get cameras
let devices = try await YI.Device.list()

// Get alerts
let alerts = try await YI.Alerts.list(days: 7)
```

## Topics

### Essentials

- ``YI``
- ``YI/Region``
- ``YI/Error``

### Authentication

- ``YIAuthService``
- ``YIUser``

### Device Management

- ``YIDeviceService``
- ``YIDevice``
- ``YIDeviceTNPInfo``
- ``YIPairingSession``

### Alerts

- ``YIAlertService``
- ``YIAlert``

### Account

- ``YIAccountService``
