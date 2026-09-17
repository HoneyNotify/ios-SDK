# HoneyNotify iOS SDK

The HoneyNotify iOS SDK registers APNs devices, maintains user identity and tags across token refreshes, parses notification payloads, and reports notification lifecycle events.

The canonical source lives in [`sdks/ios`](https://github.com/charlesbradber/HoneyNotify/tree/main/sdks/ios). Changes merged there are tested and mirrored automatically to this repository.

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

Pass the APNs token received by your app delegate to the SDK:

```swift
let deviceId = try await honeyNotify.register(
    deviceToken: deviceToken,
    externalUserId: "customer-123",
    tags: ["plan": "pro"]
)
```

Use `refresh(deviceToken:)` after APNs rotates the token, `identify` after login, `logout` on sign-out, and `track(event:notificationId:)` from notification handlers. When verified identity is enabled, obtain the ES256 identity token from your backend and pass it to `register` or `identify`.

`HoneyNotifyMediaAttachment` can be used from a Notification Service Extension to download a rich notification image.

## Test

```bash
swift test
```
