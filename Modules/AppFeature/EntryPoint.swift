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
  @State private var didApplyInitialPath = false
  @FetchAll var children: [Child]

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
    .onChange(of: children, initial: true) { _, _ in
      applyInitialPathIfNeeded()
    }
  }

  @MainActor
  private func applyInitialPathIfNeeded() {
    guard !didApplyInitialPath else { return }

    didApplyInitialPath = true

    guard
      path.isEmpty,
      children.count == 1,
      let child = children.first
    else { return }

    path = [.childDetail(child)]
  }
}
