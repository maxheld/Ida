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


struct ChildDetailView: View {
  
  @CasePathable
  enum Destination {
    case itemForm(Item.Draft)
  }
  
  @FetchAll(
    Item.none,
//      .where { $0.child.eq(child.id) }
//      .order { $0.date.desc() },
    animation: .default
  ) var items: [Item]
  
  let child: Child
  
  var groupedItems: [(key: Date, value: [Item])] {
    let grouped = Dictionary(grouping: items) { $0.date.startOfDay() }
    
    return grouped
      .sorted { $0.key > $1.key } // newest day first
  }
  
  @State var destination: Destination?
  @State var sharedRecord: SharedRecord?
  @Dependency(\.defaultSyncEngine) var syncEngine
  @Dependency(\.defaultDatabase) var database

  var body: some View {
    List {
      if !items.isEmpty {
        ForEach(groupedItems, id: \.key) { group in
          Section(
            header: Text("\(group.key.customFormatted())")
          ) {
            ForEach(group.value) { item in
              Button {
                destination = .itemForm(.init(item))
              } label: {
                ItemRow(item: item)
                  .buttonStyle(.borderless)
              }
            }
            .onDelete { indexSet in
              deleteRows(groupDay: group.key, at: indexSet)
            }
          }
        }
      }
    }
    .task { await task() }
    .sheet(item: $destination.itemForm, id: \.id) { itemDraft in
      NavigationStack {
        ItemFormView(item: itemDraft)
          .navigationTitle("New Item")
      }
      .presentationDetents([.medium, .large])
      .presentationDragIndicator(.visible)
    }
    .navigationTitle(child.name)
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button {
          print("Share tapped")
        } label: {
          Image(systemName: "square.and.arrow.up")
        }
      }
      
      ToolbarItemGroup(placement: .bottomBar) {
        Spacer()
        
        Button {
          addButtonTapped()
        } label: {
          Image(systemName: "plus")
        }
        .buttonStyle(.glassProminent)
      }
    }
  }

  func deleteRows(groupDay: Date, at indexSet: IndexSet) {
    withErrorReporting {
      try database.write { db in
        for index in indexSet {
          guard
            let group = groupedItems.first(where: { $0.key == groupDay })
          else { continue }
          
          try Item
            .find(group.value[index].id)
            .delete()
            .execute(db)
        }
      }
    }
  }
  
  func addButtonTapped() {
    destination = .itemForm(Item.Draft(childID: child.id))
  }
  
  func shareButtonTapped() {
//    Task {
//      sharedRecord = try await syncEngine.share(record: items) { share in
//        share[CKShare.SystemFieldKey.title] = "Join my counter!"
//      }
//    }
  }
  private func task() async {
    await withErrorReporting {
      try await $items.load(
        Item
          .where { $0.childID.eq(child.id) }
          .order { $0.date.desc() },
        animation: .default
      )
    }
  }
}

extension Date {
  func startOfDay() -> Date {
    Calendar.current.startOfDay(for: self)
  }
  
  func customFormatted() -> String {
    self.formatted(date: .complete, time: .omitted)
  }
}


#Preview {
  let _ = try! prepareDependencies {
    try $0.bootstrapDatabase()
  }
  NavigationStack {
    ForEach(0...1, id: \.self) { _ in
      ItemRow(item: .init(id: UUID(), childID: UUID(1)))
    }
  }
}
