import Foundation
import UserNotifications

extension String {
  public nonisolated static let categoryIdentifier = "daily.item.reminder"
  public nonisolated static let addActionIdentifier = "daily.item.reminder.add"
  public nonisolated static let userInfoChildIDKey = "childID"
  public nonisolated static let userInfoDescriptionKey = "description"
  public nonisolated static let userInfoSeriesIDKey = "seriesID"
  public nonisolated static let userInfoRecurrenceKey = "recurrence"
  public nonisolated static let userInfoWeekdaysKey = "weekdays"
}

extension UNUserNotificationCenter {
  @MainActor
  public func registerCategories() {
    let addAction = UNNotificationAction(
      identifier: .addActionIdentifier,
      title: String(localized: "reminder.notification.action.add", bundle: .module),
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
