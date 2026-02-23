import CustomDump
import Dependencies
import DependenciesTestSupport
import Foundation
import Sharing
import SQLiteData
import Testing

@testable import AppFeature

@Suite(
  .serialized,
  .dependency(\.date.now, Date(timeIntervalSince1970: 1_700_000_000)),
  .dependency(\.uuid, .incrementing),
  .dependency(\.calendar, Calendar(identifier: .gregorian)),
  .dependencies {
    try $0.bootstrapDatabase(
      seedData: false,
      containerIdentifierOverride: "test"
    )
  }
)
struct AppDelegateTests {
  @Dependency(\.defaultDatabase) var database
  @Shared(.isReminderSkipEnabled) var isReminderSkipEnabled

  let child = Child(id: UUID(1), name: "Mila")

  @Test
  func shouldSuppressReminderReturnsFalseWhenSettingDisabled() throws {
    setReminderSuppressionEnabled(false)
    try insertChild(child)
    try insertItem(
      Item(
        id: UUID(2),
        childID: child.id,
        date: Date(timeIntervalSince1970: 1_700_000_123),
        description: "Vitamin D"
      )
    )
    let appDelegate = AppDelegate()

    let result = appDelegate.shouldSuppressReminder(
      childID: child.id,
      description: "Vitamin D"
    )

    expectNoDifference(result, false)
  }

  @Test
  func shouldSuppressReminderReturnsTrueWhenSettingEnabledAndExactSameDayMatchExists() throws {
    setReminderSuppressionEnabled(true)
    defer { setReminderSuppressionEnabled(false) }

    try insertChild(child)
    try insertItem(
      Item(
        id: UUID(3),
        childID: child.id,
        date: Date(timeIntervalSince1970: 1_700_000_123),
        description: "Vitamin D"
      )
    )
    let appDelegate = AppDelegate()

    let result = appDelegate.shouldSuppressReminder(
      childID: child.id,
      description: "Vitamin D"
    )

    expectNoDifference(result, true)
  }

  @Test(
    .dependencies {
      $0.date.now = Date(timeIntervalSince1970: 1_700_086_500)
    }
  )
  func shouldSuppressReminderReturnsFalseForDifferentDay() throws {
    setReminderSuppressionEnabled(true)
    defer { setReminderSuppressionEnabled(false) }

    try insertChild(child)
    try insertItem(
      Item(
        id: UUID(4),
        childID: child.id,
        date: Date(timeIntervalSince1970: 1_700_000_123),
        description: "Vitamin D"
      )
    )
    let appDelegate = AppDelegate()

    let result = appDelegate.shouldSuppressReminder(
      childID: child.id,
      description: "Vitamin D"
    )

    expectNoDifference(result, false)
  }

  @Test
  func shouldSuppressReminderReturnsFalseForNonExactDescriptionMatch() throws {
    setReminderSuppressionEnabled(true)
    defer { setReminderSuppressionEnabled(false) }

    try insertChild(child)
    try insertItem(
      Item(
        id: UUID(5),
        childID: child.id,
        date: Date(timeIntervalSince1970: 1_700_000_123),
        description: "Vitamin D"
      )
    )
    let appDelegate = AppDelegate()

    let result = appDelegate.shouldSuppressReminder(
      childID: child.id,
      description: "vitamin d"
    )

    expectNoDifference(result, false)
  }

  private func setReminderSuppressionEnabled(_ enabled: Bool) {
    $isReminderSkipEnabled.withLock { $0 = enabled }
  }

  private func insertChild(_ child: Child) throws {
    try database.write { [child] db in
      try Child
        .upsert { Child.Draft(id: child.id, name: child.name) }
        .execute(db)
    }
  }

  private func insertItem(_ item: Item) throws {
    try database.write { [item] db in
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
