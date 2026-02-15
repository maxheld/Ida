import CasePaths
import OSLog
import SQLiteData
import SwiftUI
import SwiftUINavigation
import UserNotifications

public struct EntryPoint: View {
  @CasePathable
  @dynamicMemberLookup
  enum Path: Hashable {
    case childDetail(Child)
  }

  @Dependency(\.context) var context

  @State var path: [Path] = []

  public init() {
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

  public var body: some View {
    NavigationStack(path: $path) {
      ChildListView()
        .navigationDestination(for: EntryPoint.Path.self) { path in
          switch path {
          case let .childDetail(child):
            ChildDetailView(child: child)
          }
        }
    }
    .task { await task() }
  }

  private func task() async {
    @FetchAll var children: [Child]

    if children.count == 1, let child = children.first {
      path.append(.childDetail(child))
    }
  }
}

private let logger = Logger(subsystem: "Ida", category: "EntryPoint")
