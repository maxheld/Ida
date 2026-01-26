import CloudKit
import SQLiteData
import SwiftUI
import SwiftUINavigation

struct ChildListView: View {
  @Selection struct Row: Identifiable {
    var id: UUID { child.id }
    let child: Child
    let isShared: Bool
  }

  @FetchAll(
    Row.none,
    animation: .default
  )
  var rows: [Row]

  @State var isNewChildAlertPresented = false
  @State var newChildName = ""
  
  @Dependency(\.defaultDatabase) var database
  
  var body: some View {
    List {
      if !rows.isEmpty {
        ForEach(rows) { row in
          NavigationLink {
            ChildDetailView(child: row.child)
          } label: {
            HStack {
              if row.isShared {
                Image(systemName: "checkmark.icloud.fill")
                  .foregroundStyle(.accent)
              }
              Text(row.child.name)
            }
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
          .disabled(newChildName.isEmpty)

          Button(.cancel, role: .cancel) { }
        }
      }
    }
    .task { await loadRows() }
  }

  private func loadRows() async {
    _ = await withErrorReporting {
      try await $rows.load(
        Child
          .order(by: \.name)
          .leftJoin(SyncMetadata.all) { $0.syncMetadataID.eq($1.id) }
          .select {
            Row.Columns(child: $0, isShared: $1.isShared.ifnull(false))
          },
        animation: .default
      )
    }
  }

  private func deleteRows(at indexSet: IndexSet) {
    withErrorReporting {
      try database.write { db in
        for index in indexSet {
          try Child
            .find(rows[index].child.id)
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
