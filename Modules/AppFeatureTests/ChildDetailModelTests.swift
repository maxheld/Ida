import CustomDump
import Dependencies
import DependenciesTestSupport
import Foundation
import SQLiteData
import Testing

@testable import AppFeature

@Suite(
  .serialized,
  .dependency(\.date.now, Date(timeIntervalSince1970: 1_234_567_890)),
  .dependency(\.uuid, .incrementing),
  .dependencies {
    try $0.bootstrapDatabase(
      seedData: false,
      containerIdentifierOverride: "test"
    )
  }
)
struct ChildDetailModelTests {
  @Dependency(\.defaultDatabase) var database

  let child = Child(id: UUID(1), name: "Mila")

  @Test
  func initialState() {
    let model = ChildDetailModel(child: child)

    expectNoDifference(model.child.id, child.id)
    expectNoDifference(model.child.name, child.name)
    expectNoDifference(model.filteredItems.map(\.description), [])
    expectNoDifference(model.groupedItems.map(\.value).map { $0.map(\.description) }, [[String]]())
    expectNoDifference(model.isFiltering, false)
    expectNoDifference(model.destination != nil, false)
    expectNoDifference(model.sharedRecord != nil, false)
    expectNoDifference(model.caughtError != nil, false)
    expectNoDifference(model.isPreparingSharedRecord, false)
    expectNoDifference(model.reminderChild != nil, false)
    expectNoDifference(model.searchText, "")
  }

  @Test
  func addButtonTappedPresentsNewItemDraftForChild() {
    let model = ChildDetailModel(child: child)

    model.addButtonTapped()

    guard case let .itemForm(draft)? = model.destination else {
      Issue.record("Expected item form destination after tapping add")
      return
    }
    expectNoDifference(draft.childID, child.id)
  }

  @Test
  func itemTappedPresentsExistingItemDraft() {
    let model = ChildDetailModel(child: child)
    let item = Item(
      id: UUID(2),
      childID: child.id,
      date: Date(timeIntervalSince1970: 1_700_000_000),
      description: "Snack time"
    )

    model.itemTapped(item)

    guard case let .itemForm(draft)? = model.destination else {
      Issue.record("Expected item form destination after tapping item")
      return
    }
    expectNoDifference(draft.id, item.id)
    expectNoDifference(draft.childID, item.childID)
    expectNoDifference(draft.date, item.date)
    expectNoDifference(draft.description, item.description)
  }

  @Test
  func reminderButtonTappedPresentsReminderSheet() {
    let model = ChildDetailModel(child: child)

    model.reminderButtonTapped()

    expectNoDifference(model.reminderChild?.id, child.id)
    expectNoDifference(model.reminderChild?.name, child.name)
  }

  @Test
  func searchFiltersAndGroupsSameAsViewLogic() throws {
    try insertChild(child)
    try insertItems([
      Item(
        id: UUID(10),
        childID: child.id,
        date: Date(timeIntervalSince1970: 1_700_100_000),
        description: "Bike ride"
      ),
      Item(
        id: UUID(11),
        childID: child.id,
        date: Date(timeIntervalSince1970: 1_700_099_000),
        description: "Pool time"
      ),
      Item(
        id: UUID(12),
        childID: child.id,
        date: Date(timeIntervalSince1970: 1_700_000_000),
        description: "Drawing class"
      ),
    ])
    let model = ChildDetailModel(child: child)

    expectNoDifference(
      model.groupedItems.map(\.value).map { $0.map(\.description) },
      [["Bike ride", "Pool time"], ["Drawing class"]]
    )
    expectNoDifference(model.isFiltering, false)

    model.searchText = "  drw cls  "

    expectNoDifference(model.isFiltering, true)
    expectNoDifference(model.filteredItems.map(\.description), ["Drawing class"])
    expectNoDifference(
      model.groupedItems.map(\.value).map { $0.map(\.description) },
      [["Drawing class"]]
    )
  }

  @Test
  func deleteRowsDeletesOnlySelectedIndexInGroup() throws {
    try insertChild(child)
    try insertItems([
      Item(
        id: UUID(20),
        childID: child.id,
        date: Date(timeIntervalSince1970: 1_700_100_000),
        description: "Bike ride"
      ),
      Item(
        id: UUID(21),
        childID: child.id,
        date: Date(timeIntervalSince1970: 1_700_099_000),
        description: "Pool time"
      ),
      Item(
        id: UUID(22),
        childID: child.id,
        date: Date(timeIntervalSince1970: 1_700_000_000),
        description: "Drawing class"
      ),
    ])
    let model = ChildDetailModel(child: child)
    guard let newestGroupDay = model.groupedItems.first?.key else {
      Issue.record("Expected at least one group in grouped items")
      return
    }

    model.deleteRows(groupDay: newestGroupDay, at: IndexSet(integer: 1))

    let descriptions = try database.read { db in
      try Item
        .where { $0.childID.eq(child.id) }
        .order { $0.date.desc() }
        .fetchAll(db)
        .map(\.description)
    }
    expectNoDifference(descriptions, ["Bike ride", "Drawing class"])
  }

  private func insertChild(_ child: Child) throws {
    try database.write { [child] db in
      try Child
        .upsert { Child.Draft(id: child.id, name: child.name) }
        .execute(db)
    }
  }

  private func insertItems(_ items: [Item]) throws {
    try database.write { [items] db in
      for item in items {
        try Item
          .upsert {
            Item.Draft(
              id: item.id,
              childID: item.childID,
              date: item.date,
              description: item.description
            )
          }
          .execute(db)
      }
    }
  }
}
