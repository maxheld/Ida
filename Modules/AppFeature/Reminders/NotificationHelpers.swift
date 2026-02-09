import Foundation
import UserNotifications

extension String {
  public static let categoryIdentifier = "daily.item.reminder"
  public static let addActionIdentifier = "daily.item.reminder.add"
  public static let userInfoChildIDKey = "childID"
  public static let userInfoDescriptionKey = "description"
}

extension UNUserNotificationCenter {
  public func registerCategories() {
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
