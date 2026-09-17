import Foundation
import UserNotifications

public enum HoneyNotifyMediaAttachment {
    public static func attach(to content: UNMutableNotificationContent, userInfo: [AnyHashable: Any]) async {
        guard let rawURL = userInfo["honeynotify_image_url"] as? String, let remoteURL = URL(string: rawURL) else { return }
        do {
            let (temporaryURL, response) = try await URLSession.shared.download(from: remoteURL)
            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else { return }
            let extensionName = remoteURL.pathExtension.isEmpty ? "jpg" : remoteURL.pathExtension
            let localURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension(extensionName)
            try FileManager.default.moveItem(at: temporaryURL, to: localURL)
            content.attachments = [try UNNotificationAttachment(identifier: "honeynotify-media", url: localURL)]
        } catch {
            return
        }
    }
}
