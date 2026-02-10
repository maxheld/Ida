import Foundation
import UserNotifications

extension String {
  public nonisolated static let categoryIdentifier = "daily.item.reminder"
  public nonisolated static let addActionIdentifier = "daily.item.reminder.add"
  public nonisolated static let userInfoChildIDKey = "childID"
  public nonisolated static let userInfoDescriptionKey = "description"
}

extension UNUserNotificationCenter {
  public nonisolated func registerCategories() {
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
