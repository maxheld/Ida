import AppFeature
import SwiftUI

@main
struct IdaApp: App {
  @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
  
  var body: some Scene {
    WindowGroup {
      EntryPoint()
    }
  }
}
