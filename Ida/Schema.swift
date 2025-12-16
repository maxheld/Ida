import Foundation
import OSLog
import SQLiteData

@Table
nonisolated struct Item: Identifiable {
  let id: UUID
  let childID: Child.ID
  var date: Date = .init()
  var description: String = ""
}

@Table
nonisolated struct Child: Identifiable, Hashable {
  let id: UUID
  var name: String = ""
}

extension DependencyValues {
  mutating func bootstrapDatabase(seedData: Bool = false) throws {
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
    migrator.registerMigration("Create tables") { [seedData] db in
      try #sql(
        """
        CREATE TABLE "childs" (
          "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
          "name" TEXT NOT NULL DEFAULT ''
        ) STRICT
        """
      )
      .execute(db)
      
      try #sql(
        """
        CREATE TABLE "items" (
          "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
          "childID" TEXT NOT NULL REFERENCES "childs"("id") ON DELETE CASCADE,  
          "date" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT CURRENT_TIMESTAMP,
          "description" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT ''
        ) STRICT
        """
      )
      .execute(db)
      
      @Dependency(\.context) var context
      if context != .live && seedData {
        try db.seedSampleData()
      }
    }
    try migrator.migrate(database)
    defaultDatabase = database
    defaultSyncEngine = try SyncEngine(
      for: defaultDatabase,
      tables: Child.self, Item.self
    )
  }
}

private let logger = Logger(subsystem: "Ida", category: "Database")

#if DEBUG
  extension Database {
    nonisolated func seedSampleData() throws {
      @Dependency(\.date.now) var now
      @Dependency(\.uuid) var uuid
      try seed {
        Child(id: UUID(1), name: "Ida")
        Child(id: UUID(2), name: "Max")
        Item.Draft(
          id: uuid(),
          childID: UUID(1),
          date: now.addingTimeInterval(-60 * 60 * 24 * 190),
          description: "🥑💦"
        )
      }
    }
  }
#endif
