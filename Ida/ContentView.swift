import CloudKit
import SQLiteData
import SwiftUI
import SwiftUINavigation

struct CountersListView: View {
  
  @CasePathable
  enum Destination {
    case itemForm(Item.Draft)
  }
  
  @FetchAll(
    Item.order { $0.date.desc() },
    animation: .default
  ) var items: [Item]
  
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
//        ForEach(groupedItems, id: \.key) { group in
//          Section(
//            header: Text("\(group.key)")
//          ) {
//            ForEach(group.value) { item in
//              ItemRow() // ADD ITEM HERE
//                .buttonStyle(.borderless)
//            }
//            .onDelete { indexSet in
//              deleteRows(at: indexSet)
//            }
//          }
//        }
        Section {
          ForEach(items) { item in
            Button {
              destination = .itemForm(.init(item))
            } label: {
              ItemRow(item: item)
                .buttonStyle(.borderless)
            }
          }
          .onDelete { indexSet in
            deleteRows(at: indexSet)
          }
        }
      }
    }
    .sheet(item: $destination.itemForm, id: \.id) { itemDraft in
      NavigationStack {
        ItemFormView(item: itemDraft)
          .navigationTitle("New Item")
      }
      .presentationDetents([.medium, .large])
      .presentationDragIndicator(.visible)
    }
    .navigationTitle("Items")
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

  func deleteRows(at indexSet: IndexSet) {
    withErrorReporting {
      try database.write { db in
        for index in indexSet {
          try Item.find(items[index].id).delete()
            .execute(db)
        }
      }
    }
  }
  
  func addButtonTapped() {
    destination = .itemForm(Item.Draft())
  }
  
  func shareButtonTapped() {
//    Task {
//      sharedRecord = try await syncEngine.share(record: items) { share in
//        share[CKShare.SystemFieldKey.title] = "Join my counter!"
//      }
//    }
  }
}





extension Date {
  func startOfDay() -> Date {
    Calendar.current.startOfDay(for: self)
  }
}


#Preview {
  let _ = try! prepareDependencies {
    try $0.bootstrapDatabase()
  }
  NavigationStack {
    ForEach(0...1, id: \.self) { _ in
      ItemRow(item: .init(id: UUID()))
    }
  }
}
