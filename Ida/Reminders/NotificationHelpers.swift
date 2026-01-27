import Foundation
import UserNotifications

extension String {
  static let categoryIdentifier = "daily.item.reminder"
  static let addActionIdentifier = "daily.item.reminder.add"
  static let userInfoChildIDKey = "childID"
  static let userInfoDescriptionKey = "description"
}

extension UNUserNotificationCenter {
  func registerCategories() {
    let addAction = UNNotificationAction(
      identifier: .addActionIdentifier,
      title: String(localized: "reminder.notification.action.add"),
      options: [.foreground]
    )
    let category = UNNotificationCategory(
      identifier: .categoryIdentifier,
      actions: [addAction],
      intentIdentifiers: [],
      options: .customDismissAction
    )
    setNotificationCategories([category])
  }
}
