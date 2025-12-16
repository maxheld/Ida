import CloudKit
import SQLiteData
import SwiftUI
import SwiftUINavigation

struct ChildListView: View {
  @FetchAll(animation: .default) var children: [Child]
  @State var isNewChildAlertPresented = false
  @State var newChildName = ""
  
  @Dependency(\.defaultDatabase) var database
  
  var body: some View {
    List {
      if !children.isEmpty {
        ForEach(children) { child in
          NavigationLink {
            ChildDetailView(child: child)
          } label: {
            Text(child.name)
          }
        }
        .onDelete { indexSet in
          deleteRows(at: indexSet)
        }
      } else {
        ContentUnavailableView(
          .childListEmptyTitle,
          systemImage: "figure.2.and.child.holdinghands",
          description: Text(.childListEmptyDescription)
        )
      }
    }
    .navigationTitle(.childListTitle)
    .toolbar {
      ToolbarItemGroup(placement: .bottomBar) {
        Spacer()
        
        Button {
          newChildName = ""
          isNewChildAlertPresented = true
        } label: {
          Image(systemName: "plus")
        }
        .alert(
          .childListNewChildTitle,
          isPresented: $isNewChildAlertPresented
        ) {
          TextField(.childListNewChildNameLabel, text: $newChildName)
          Button(.save) {
            withErrorReporting {
              try database.write { db in
                try Child
                  .upsert { Child.Draft(name: newChildName) }
                  .execute(db)
              }
            }
          }
          Button(.cancel, role: .cancel) { }
        }
      }
    }
  }
  
  private func deleteRows(at indexSet: IndexSet) {
    withErrorReporting {
      try database.write { db in
        for index in indexSet {
          try Child
            .find(children[index].id)
            .delete()
            .execute(db)
        }
      }
    }
  }
}

#Preview {
  let _ = try! prepareDependencies {
    try $0.bootstrapDatabase(seedData: true)
  }
  NavigationStack {
    ChildListView()
  }
}
