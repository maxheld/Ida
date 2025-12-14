import Foundation
import OSLog
import SQLiteData

//@Table
//nonisolated struct Counter: Identifiable {
//  let id: UUID
//  var count = 0
//}

//@Selection
struct ItemsGroupedByDay {
  let day: Date
  let items: [Item]
}

@Table
nonisolated struct Item: Identifiable {
  let id: UUID
  var date: Date = .init()
  var description: String = ""
}


extension DependencyValues {
  mutating func bootstrapDatabase() throws {
    let database = try SQLiteData.defaultDatabase()
    logger.debug(
      """
      App database
      open "\(database.path)"
      """
    )

    var migrator = DatabaseMigrator()
    #if DEBUG
      migrator.eraseDatabaseOnSchemaChange = true
    #endif
    migrator.registerMigration("Create tables") { db in
      try #sql(
        """
        CREATE TABLE "items" (
          "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
          "date" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT CURRENT_TIMESTAMP,
          "description" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT ''
        ) STRICT
        """
      )
      .execute(db)
    }
    try migrator.migrate(database)
    defaultDatabase = database
    defaultSyncEngine = try SyncEngine(
      for: defaultDatabase,
      tables: Item.self
    )
  }
}

private let logger = Logger(subsystem: "Ida", category: "Database")

