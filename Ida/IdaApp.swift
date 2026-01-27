import CasePaths
import CloudKit
import SQLiteData
import SwiftUI
import SwiftUINavigation
import UserNotifications

@main
struct IdaApp: App {
  @CasePathable
  @dynamicMemberLookup
  enum Path: Hashable {
    case childDetail(Child)
  }
  
  @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
  @Dependency(\.context) var context
  
  @State var path: [Path] = []
  
  init() {
    if context == .live {
      try! prepareDependencies {
        try $0.bootstrapDatabase()
      }
    }
  }
  
  var body: some Scene {
    WindowGroup {
      NavigationStack(path: $path) {
        ChildListView()
          .navigationDestination(for: IdaApp.Path.self) { path in
            switch path {
            case let .childDetail(child):
              ChildDetailView(child: child)
            }
          }
      }
      .task { await task() }
    }
  }
  
  private func task() async {
    @FetchAll var children: [Child]
  
    if children.count == 1, let child = children.first {
      path.append(.childDetail(child))
    }
  }
}

class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
  @Dependency(\.defaultDatabase) var database

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    let center = UNUserNotificationCenter.current()
    center.delegate = self
    center.registerCategories()

    return true
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .sound])
  }

  func userNotificationCenter(
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

  func application(
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

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  @Dependency(\.defaultSyncEngine) var syncEngine
  var window: UIWindow?
  
  func windowScene(
    _ windowScene: UIWindowScene,
    userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
  ) {
    Task { @MainActor in
      await withErrorReporting {
        try await syncEngine.acceptShare(metadata: cloudKitShareMetadata)
      }
    }
  }
  
  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let cloudKitShareMetadata = connectionOptions.cloudKitShareMetadata
    else { return }
    Task { @MainActor in
      await withErrorReporting {
        try await syncEngine.acceptShare(metadata: cloudKitShareMetadata)
      }
    }
  }
}
