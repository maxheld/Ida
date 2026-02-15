import AppFeature
import Dependencies
import OSLog
import SwiftUI

@main
struct IdaApp: App {
  @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate

  @Dependency(\.context) var context

  init() {
    guard context == .live else { return }

    do {
      try prepareDependencies {
        try $0.bootstrapDatabase()
      }
    } catch {
      let nsError = error as NSError
      let message =
        """
        Failed to bootstrap app dependencies.
        error: \(String(reflecting: error))
        nserror: \(nsError.domain)(\(nsError.code)) userInfo=\(nsError.userInfo)
        """
      logger.fault("\(message, privacy: .public)")
      fatalError(message)
    }
  }

  var body: some Scene {
    WindowGroup {
      EntryPoint()
    }
  }
}

private let logger = Logger(subsystem: "Ida", category: "IdaApp")
