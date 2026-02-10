import AppFeature
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
