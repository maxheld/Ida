import CloudKit
import SQLiteData
import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
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
