import Foundation
import SQLiteData

func hasTrackedEntryToday(
  childID: Child.ID,
  description: String
) -> Bool {
  @Dependency(\.date.now) var now
  @Dependency(\.calendar) var calendar
  @Dependency(\.defaultDatabase) var database

  let containsEntry = try? database.read { db in
    let items = try Item
      .where { $0.childID.eq(childID) }
      .where { $0.description.eq(description) }
      .fetchAll(db)

    return items.contains { item in
      calendar.isDate(item.date, inSameDayAs: now)
    }
  }

  return containsEntry ?? false
}
