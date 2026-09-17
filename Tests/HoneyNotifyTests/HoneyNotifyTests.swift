import Foundation
import XCTest
@testable import HoneyNotify

final class HoneyNotifyTests: XCTestCase {
    func testNotificationPayloadParsing() throws {
        let client = HoneyNotify(
            baseURL: try XCTUnwrap(URL(string: "https://api.honeynotify.com")),
            clientKey: "ps_public_test"
        )

        let notification = client.notification(from: [
            "honeynotify_notification_id": "notification-id",
            "honeynotify_click_url": "https://example.com/account",
            "honeynotify_image_url": "https://example.com/image.png",
            "honeynotify_interruption_level": "time_sensitive",
            "data": ["order_id": "order-123"],
        ])

        XCTAssertEqual(notification.id, "notification-id")
        XCTAssertEqual(notification.clickURL?.absoluteString, "https://example.com/account")
        XCTAssertEqual(notification.imageURL?.absoluteString, "https://example.com/image.png")
        XCTAssertEqual(notification.interruptionLevel, .timeSensitive)
        XCTAssertEqual(notification.data["order_id"] as? String, "order-123")
    }

    func testUnknownInterruptionLevelDefaultsToActive() throws {
        let client = HoneyNotify(
            baseURL: try XCTUnwrap(URL(string: "https://api.honeynotify.com")),
            clientKey: "ps_public_test"
        )

        XCTAssertEqual(
            client.notification(from: ["honeynotify_interruption_level": "urgent"]).interruptionLevel,
            .active
        )
    }

    func testCriticalPermissionIsOptIn() {
        XCTAssertFalse(HoneyNotify.authorizationOptions().contains(.criticalAlert))
        XCTAssertTrue(HoneyNotify.authorizationOptions(includeCriticalAlerts: true).contains(.criticalAlert))
    }
}
