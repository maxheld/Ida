import CasePaths
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

  @State var path: [Path] = []

  public init() {}

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
