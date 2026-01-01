import CloudKit
import SQLiteData
import SwiftUI
import SwiftUINavigation

struct ChildDetailView: View {
  @CasePathable
  enum Destination {
    case itemForm(Item.Draft)
  }
  
  @FetchAll(
    Item.none,
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
            header: Text(group.key.customFormatted())
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
      } else {
        ContentUnavailableView(
          .childDetailEmptyTitle(child.name),
          systemImage: "figure.2.and.child.holdinghands",
          description: Text(.childDetailEmptyDescription)
        )
      }
    }
    .task { await task() }
    .sheet(item: $destination.itemForm, id: \.id) { itemDraft in
      ItemFormSheet(itemDraft: itemDraft)
    }
    .navigationTitle(child.name)
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button {
          shareButtonTapped()
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
    Task {
      sharedRecord = try await syncEngine.share(record: child) { share in
        share[CKShare.SystemFieldKey.title] = String(localized: "child.detail.share.title \(child.name)")
        share.publicPermission = .readWrite
      }
    }
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

private struct ItemFormSheet: View {
  var itemDraft: Item.Draft
  
  var body: some View {
    NavigationStack {
      ItemFormView(item: itemDraft)
        .navigationTitle(.itemFormTitle)
    }
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
  }
}

private extension Date {
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
