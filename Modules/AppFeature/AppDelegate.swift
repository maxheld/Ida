import UIKit
import SQLiteData
import Sharing
import UserNotifications

public final class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
  @Dependency(\.defaultDatabase) var database
  @Shared(.isReminderSkipEnabled) private var isReminderSkipEnabled

  public func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    let center = UNUserNotificationCenter.current()
    center.delegate = self
    center.registerCategories()

    return true
  }

  public func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if
      notification.request.content.categoryIdentifier == .categoryIdentifier,
      let payload = reminderPayload(from: notification.request.content.userInfo),
      shouldSuppressReminder(childID: payload.childID, description: payload.description)
    {
      completionHandler([])
      return
    }

    completionHandler([.banner, .sound])
  }

  public func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    defer { completionHandler() }

    guard
      response.actionIdentifier == .addActionIdentifier,
      let payload = reminderPayload(
        from: response.notification.request.content.userInfo
      )
    else { return }

    guard !shouldSuppressReminder(
      childID: payload.childID,
      description: payload.description
    ) else { return }

    withErrorReporting {
      try database.write { db in
        try Item
          .upsert {
            Item.Draft(
              childID: payload.childID,
              description: payload.description
            )
          }
          .execute(db)
      }
    }
  }

  public func application(
    _ application: UIApplication,
    configurationForConnecting connectingSceneSession: UISceneSession,
    options: UIScene.ConnectionOptions
  ) -> UISceneConfiguration {
    let configuration = UISceneConfiguration(
      name: "Default Configuration",
      sessionRole: connectingSceneSession.role
    )
    configuration.delegateClass = SceneDelegate.self
    return configuration
  }

  func shouldSuppressReminder(
    childID: Child.ID,
    description: String
  ) -> Bool {
    guard isReminderSkipEnabled else { return false }

    return hasTrackedEntryToday(childID: childID, description: description)
  }

  private func reminderPayload(
    from userInfo: [AnyHashable: Any]
  ) -> (childID: Child.ID, description: String)? {
    guard
      let childIDString = userInfo[String.userInfoChildIDKey] as? String,
      let childID = UUID(uuidString: childIDString)
    else { return nil }

    let description = userInfo[String.userInfoDescriptionKey] as? String ?? ""
    return (childID, description)
  }
}
