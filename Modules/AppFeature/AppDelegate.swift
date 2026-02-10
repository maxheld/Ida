import UIKit
import SQLiteData
import UserNotifications

public final class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
  @Dependency(\.defaultDatabase) var database

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
    completionHandler([.banner, .sound])
  }

  public func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    defer { completionHandler() }

    guard response.actionIdentifier == .addActionIdentifier else { return }
    let userInfo = response.notification.request.content.userInfo

    guard
      let childIDString = userInfo[String.userInfoChildIDKey] as? String,
      let childID = UUID(uuidString: childIDString)
    else { return }

    let description = userInfo[String.userInfoDescriptionKey] as? String ?? ""

    withErrorReporting {
      try database.write { db in
        try Item
          .upsert { Item.Draft(childID: childID, description: description) }
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
}
