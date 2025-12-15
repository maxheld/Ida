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
      }
    }
    .navigationTitle("Children")
    .toolbar {
      ToolbarItemGroup(placement: .bottomBar) {
        Spacer()
        
        Button {
          newChildName = ""
          isNewChildAlertPresented = true
        } label: {
          Image(systemName: "plus")
        }
        .buttonStyle(.glass)
        .alert("New child", isPresented: $isNewChildAlertPresented) {
          TextField("Child name", text: $newChildName)
          Button("Save") {
            withErrorReporting {
              try database.write { db in
                try Child
                  .upsert { Child.Draft(name: newChildName) }
                  .execute(db)
              }
            }
          }
          Button("Cancel", role: .cancel) { }
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
