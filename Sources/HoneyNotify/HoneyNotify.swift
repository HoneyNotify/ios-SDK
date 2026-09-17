import Foundation
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

public enum HoneyNotifyInterruptionLevel: String, CaseIterable, Sendable {
    case passive
    case active
    case timeSensitive = "time_sensitive"
    case critical
}

public final class HoneyNotify {
    private let baseURL: URL
    private let clientKey: String
    private let session: URLSession

    public init(baseURL: URL, clientKey: String, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.clientKey = clientKey
        self.session = session
    }

    public func requestPermission(includeCriticalAlerts: Bool = false) async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(
            options: Self.authorizationOptions(includeCriticalAlerts: includeCriticalAlerts)
        )
    }

    static func authorizationOptions(includeCriticalAlerts: Bool = false) -> UNAuthorizationOptions {
        var options: UNAuthorizationOptions = [.alert, .badge, .sound]
        if includeCriticalAlerts { options.insert(.criticalAlert) }
        return options
    }

    #if canImport(UIKit)
    @MainActor public func requestPermissionAndRegister(includeCriticalAlerts: Bool = false) async throws -> Bool {
        let granted = try await requestPermission(includeCriticalAlerts: includeCriticalAlerts)
        if granted { UIApplication.shared.registerForRemoteNotifications() }
        return granted
    }
    #endif

    public func register(deviceToken: Data, externalUserId: String? = nil, tags: [String: String] = [:], identityToken: String? = nil) async throws -> String {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        var payload: [String: Any] = ["platform": "ios", "push_token": token, "tags": tags]
        payload["external_user_id"] = externalUserId
        payload["identity_token"] = identityToken
        payload["locale"] = Locale.current.identifier
        payload["timezone"] = TimeZone.current.identifier
        payload["app_version"] = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        let response = try await request(path: "/v1/devices/register", body: payload)
        guard let deviceId = response["device_id"] as? String else { throw HoneyNotifyError.invalidResponse }
        UserDefaults.standard.set(deviceId, forKey: "HoneyNotify.deviceId")
        UserDefaults.standard.set(token, forKey: "HoneyNotify.pushToken")
        UserDefaults.standard.set(externalUserId, forKey: "HoneyNotify.externalUserId")
        UserDefaults.standard.set(tags, forKey: "HoneyNotify.tags")
        return deviceId
    }

    public func refresh(deviceToken: Data) async throws -> String {
        let externalUserId = UserDefaults.standard.string(forKey: "HoneyNotify.externalUserId")
        let tags = UserDefaults.standard.dictionary(forKey: "HoneyNotify.tags") as? [String: String] ?? [:]
        return try await register(deviceToken: deviceToken, externalUserId: externalUserId, tags: tags)
    }

    public func identify(externalUserId: String, tags: [String: String] = [:], identityToken: String? = nil) async throws -> String {
        guard let token = UserDefaults.standard.string(forKey: "HoneyNotify.pushToken"), let data = Data(hex: token) else { throw HoneyNotifyError.missingPushToken }
        return try await register(deviceToken: data, externalUserId: externalUserId, tags: tags, identityToken: identityToken)
    }

    public func logout() async throws {
        guard let deviceId = UserDefaults.standard.string(forKey: "HoneyNotify.deviceId") else { return }
        var request = URLRequest(url: baseURL.appendingPathComponent("v1/devices/\(deviceId)"))
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(clientKey)", forHTTPHeaderField: "Authorization")
        let (_, response) = try await session.data(for: request)
        guard let status = (response as? HTTPURLResponse)?.statusCode, status == 200 else { throw HoneyNotifyError.requestFailed(status: (response as? HTTPURLResponse)?.statusCode ?? 0, message: nil) }
        UserDefaults.standard.removeObject(forKey: "HoneyNotify.deviceId")
        UserDefaults.standard.removeObject(forKey: "HoneyNotify.pushToken")
        UserDefaults.standard.removeObject(forKey: "HoneyNotify.externalUserId")
        UserDefaults.standard.removeObject(forKey: "HoneyNotify.tags")
    }

    public func track(event: String, notificationId: String? = nil, metadata: [String: String] = [:]) async throws {
        let standardEvents = ["received", "opened", "clicked", "dismissed"]
        var payload: [String: Any] = ["event_type": standardEvents.contains(event) ? event : "custom", "occurred_at": ISO8601DateFormatter().string(from: Date()), "metadata": metadata]
        if !standardEvents.contains(event) { payload["event_name"] = event }
        payload["notification_id"] = notificationId
        payload["device_id"] = UserDefaults.standard.string(forKey: "HoneyNotify.deviceId")
        _ = try await request(path: "/v1/events", body: payload)
    }

    public func permissionStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    public func criticalAlertPermissionStatus() async -> UNNotificationSetting {
        await UNUserNotificationCenter.current().notificationSettings().criticalAlertSetting
    }

    public func notification(from userInfo: [AnyHashable: Any]) -> HoneyNotifyNotification {
        HoneyNotifyNotification(
            id: userInfo["honeynotify_notification_id"] as? String,
            clickURL: (userInfo["honeynotify_click_url"] as? String).flatMap(URL.init(string:)),
            imageURL: (userInfo["honeynotify_image_url"] as? String).flatMap(URL.init(string:)),
            interruptionLevel: HoneyNotifyInterruptionLevel(
                rawValue: userInfo["honeynotify_interruption_level"] as? String ?? "active"
            ) ?? .active,
            data: userInfo["data"] as? [String: Any] ?? [:]
        )
    }

    public func trackReceived(userInfo: [AnyHashable: Any]) async throws {
        try await track(event: "received", notificationId: notification(from: userInfo).id)
    }

    public func trackOpened(userInfo: [AnyHashable: Any], actionId: String? = nil) async throws {
        var metadata: [String: String] = [:]
        if let actionId { metadata["action_id"] = actionId }
        try await track(event: actionId == nil ? "opened" : "clicked", notificationId: notification(from: userInfo).id, metadata: metadata)
    }

    private func request(path: String, body: [String: Any]) async throws -> [String: Any] {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: body.compactMapValues { $0 })
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(clientKey)", forHTTPHeaderField: "Authorization")
        var lastData = Data()
        var lastStatus = 0
        for attempt in 0..<3 {
            let (data, response) = try await session.data(for: request)
            lastData = data
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            lastStatus = status
            if 200..<300 ~= status {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw HoneyNotifyError.invalidResponse }
                return json
            }
            if status != 429 && status < 500 { break }
            try await Task.sleep(nanoseconds: UInt64(250_000_000 * (attempt + 1)))
        }
        let message = (try? JSONSerialization.jsonObject(with: lastData) as? [String: Any]).flatMap { ($0["error"] as? [String: Any])?["message"] as? String }
        throw HoneyNotifyError.requestFailed(status: lastStatus, message: message)
    }
}

public struct HoneyNotifyNotification {
    public let id: String?
    public let clickURL: URL?
    public let imageURL: URL?
    public let interruptionLevel: HoneyNotifyInterruptionLevel
    public let data: [String: Any]
}

private extension Data {
    init?(hex: String) {
        guard hex.count.isMultiple(of: 2) else { return nil }
        var data = Data()
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<next], radix: 16) else { return nil }
            data.append(byte)
            index = next
        }
        self = data
    }
}

public enum HoneyNotifyError: Error { case requestFailed(status: Int, message: String?), invalidResponse, missingPushToken }
