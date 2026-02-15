import Foundation
import OSLog
import SQLiteData

@Table
public nonisolated struct Item: Identifiable, Sendable {
  public let id: UUID
  public let childID: Child.ID
  public var date: Date = .init()
  public var description: String = ""
}

@Table
public nonisolated struct Child: Identifiable, Hashable, Sendable {
  public let id: UUID
  public var name: String = ""
}

extension DependencyValues {
  public mutating func bootstrapDatabase(
    seedData: Bool = false,
    containerIdentifierOverride: String? = nil
  ) throws {
    var configuration = Configuration()
    configuration.prepareDatabase { db in
      do {
        try db.attachMetadatabase(containerIdentifier: containerIdentifierOverride)
      } catch {
        throw BootstrapDatabaseError(
          step: "attach CloudKit metadatabase",
          underlying: error
        )
      }
    }

    let database: any DatabaseWriter
    do {
      database = try SQLiteData.defaultDatabase(configuration: configuration)
    } catch {
      throw BootstrapDatabaseError(
        step: "open default database",
        underlying: error
      )
    }
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
      #if DEBUG
        @Dependency(\.context) var context
        if context != .live && seedData {
          try db.seedSampleData()
        }
      #endif
    }
    migrator.registerMigration("Add item indexes") { db in
      try #sql(
        """
        CREATE INDEX IF NOT EXISTS "items_childID_date_index"
        ON "items" ("childID", "date" DESC)
        """
      )
      .execute(db)

      try #sql(
        """
        CREATE INDEX IF NOT EXISTS "items_childID_description_index"
        ON "items" ("childID", "description")
        """
      )
      .execute(db)
    }
    do {
      try migrator.migrate(database)
    } catch {
      throw BootstrapDatabaseError(
        step: "run database migrations",
        underlying: error
      )
    }
    defaultDatabase = database
    do {
      defaultSyncEngine = try SyncEngine(
        for: defaultDatabase,
        tables: Child.self, Item.self,
        containerIdentifier: containerIdentifierOverride ?? "iCloud.com.maxheld.IdaApp"
      )
    } catch {
      throw BootstrapDatabaseError(
        step: "initialize CloudKit sync engine",
        underlying: error
      )
    }
  }
}

private let logger = Logger(subsystem: "Ida", category: "Database")

private struct BootstrapDatabaseError: Error, CustomStringConvertible, LocalizedError {
  let step: String
  let underlying: any Error

  var description: String {
    let nsError = underlying as NSError
    return
      "bootstrapDatabase failed at '\(step)'; error=\(String(reflecting: underlying)); nserror=\(nsError.domain)(\(nsError.code)) userInfo=\(nsError.userInfo)"
  }

  var errorDescription: String? { description }
}

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
