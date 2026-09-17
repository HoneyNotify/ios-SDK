# HoneyNotify iOS SDK

The HoneyNotify iOS SDK registers APNs devices, maintains user identity and tags across token refreshes, parses notification payloads, and reports notification lifecycle events.

## Requirements

- iOS 15 or later
- Swift 5.9 or later
- A HoneyNotify public mobile client key (`ps_public_...`)

Public mobile client keys are restricted by the HoneyNotify API to device registration and event reporting. Never bundle a notification-send key in an app.

## Install

In Xcode, choose **File > Add Package Dependencies** and enter:

```text
https://github.com/HoneyNotify/ios-SDK.git
```

Then create the client and request notification permission:

```swift
import HoneyNotify

let honeyNotify = HoneyNotify(
    baseURL: URL(string: "https://api.honeynotify.com")!,
    clientKey: "ps_public_your_key"
)

let granted = try await honeyNotify.requestPermissionAndRegister()
```

For an app that has Apple's approved Critical Alerts entitlement, explicitly include critical-alert permission:

```swift
let granted = try await honeyNotify.requestPermissionAndRegister(includeCriticalAlerts: true)
let criticalSetting = await honeyNotify.criticalAlertPermissionStatus()
```

Do not enable this option in an app without the entitlement. A server-side `critical` interruption level cannot grant the entitlement or override the user's permission choice.

Pass the APNs token received by your app delegate to the SDK:

```swift
let deviceId = try await honeyNotify.register(
    deviceToken: deviceToken,
    externalUserId: "customer-123",
    tags: ["plan": "pro"]
)
```

Use `refresh(deviceToken:)` after APNs rotates the token, `identify` after login, `logout` on sign-out, and `track(event:notificationId:)` from notification handlers. Parsed notifications expose a typed `interruptionLevel`. When verified identity is enabled, obtain the ES256 identity token from your backend and pass it to `register` or `identify`.

`HoneyNotifyMediaAttachment` can be used from a Notification Service Extension to download a rich notification image.

## Test

```bash
swift test
```
