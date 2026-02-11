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
struct ChildListModelTests {
  @Dependency(\.defaultDatabase) var database

  @Test
  func initialState() throws {
    let model = ChildListModel()

    expectNoDifference(model.rows.map(\.child.name), [])
    expectNoDifference(model.isNewChildAlertPresented, false)
    expectNoDifference(model.newChildName, "")
  }

  @Test
  func addButtonTappedResetsDraftAndPresentsAlert() {
    let model = ChildListModel()
    model.newChildName = "Existing name"

    model.addButtonTapped()

    expectNoDifference(model.isNewChildAlertPresented, true)
    expectNoDifference(model.newChildName, "")
  }

  @Test
  func saveButtonTappedWithNonEmptyNameInsertsChild() async throws {
    let model = ChildListModel()
    model.newChildName = "Mila"

    model.saveButtonTapped()

    let children = try await database.read { db in
      try Child.order(by: \.name).fetchAll(db)
    }
    expectNoDifference(children.map(\.name), ["Mila"])

    let refreshed = ChildListModel()
    try await refreshed.$rows.load()
    expectNoDifference(refreshed.rows.map(\.child.name), ["Mila"])
    expectNoDifference(refreshed.rows.map(\.isShared), [false])
  }

  @Test
  func saveButtonTappedWithEmptyNamePersistsEmptyName() throws {
    // TOOD: Need to update the behaviour to not save on an empty string
    let model = ChildListModel()
    model.newChildName = ""

    model.saveButtonTapped()

    let children = try database.read { db in
      try Child.fetchAll(db)
    }
    expectNoDifference(children.map(\.name), [""])
  }

  @Test
  func deleteRowsWithEmptyIndexSetDoesNothing() throws {
    try insertChildren(["Charlie", "Alice", "Bob"])
    let model = ChildListModel()

    model.deleteRows(at: IndexSet())

    let names = try database.read { db in
      try Child.order(by: \.name).fetchAll(db).map(\.name)
    }
    expectNoDifference(names, ["Alice", "Bob", "Charlie"])
  }

  @Test
  func deleteRowsWithSingleIndexDeletesExpectedChild() throws {
    try insertChildren(["Charlie", "Alice", "Bob"])
    let model = ChildListModel()
    expectNoDifference(model.rows.map(\.child.name), ["Alice", "Bob", "Charlie"])

    model.deleteRows(at: IndexSet(integer: 1))

    let names = try database.read { db in
      try Child.order(by: \.name).fetchAll(db).map(\.name)
    }
    expectNoDifference(names, ["Alice", "Charlie"])
  }

  @Test
  func deleteRowsWithMultipleIndicesDeletesExpectedChildren() throws {
    try insertChildren(["Echo", "Alpha", "Delta", "Bravo", "Charlie"])
    let model = ChildListModel()
    expectNoDifference(
      model.rows.map(\.child.name),
      ["Alpha", "Bravo", "Charlie", "Delta", "Echo"]
    )

    model.deleteRows(at: IndexSet([0, 2, 4]))

    let names = try database.read { db in
      try Child.order(by: \.name).fetchAll(db).map(\.name)
    }
    expectNoDifference(names, ["Bravo", "Delta"])
  }

  private func insertChildren(_ names: [String]) throws {
    try database.write { [names] db in
      for name in names {
        try Child
          .upsert { Child.Draft(name: name) }
          .execute(db)
      }
    }
  }
}
