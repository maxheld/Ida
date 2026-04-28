import AppIntents
import AppFeature
import Dependencies
import Foundation
import SQLiteData

struct ChildEntity: AppEntity, Identifiable, Hashable, Sendable {
  static let typeDisplayRepresentation = TypeDisplayRepresentation(
    name: "intent.child.entity.type"
  )

  static let defaultQuery = ChildEntityQuery()

  let id: UUID
  let name: String

  init(id: UUID, name: String) {
    self.id = id
    self.name = name
  }

  init(_ child: Child) {
    self.id = child.id
    self.name = child.name
  }

  nonisolated var displayRepresentation: DisplayRepresentation {
    DisplayRepresentation(title: "\(name)")
  }
}

struct ChildEntityQuery: EntityQuery, EntityStringQuery {
  func entities(for identifiers: [ChildEntity.ID]) async throws -> [ChildEntity] {
    @Dependencies.Dependency(\.defaultDatabase) var database
    
    guard !identifiers.isEmpty else { return [] }

    let children = try await database.read { db in
      try Child
        .where { $0.id.in(identifiers) }
        .fetchAll(db)
    }
    return children.map(ChildEntity.init)
  }

  func suggestedEntities() async throws -> [ChildEntity] {
    @Dependencies.Dependency(\.defaultDatabase) var database

    let children = try await database.read { db in
      try Child
        .order(by: \.name)
        .fetchAll(db)
    }
    return children.map(ChildEntity.init)
  }

  func entities(matching string: String) async throws -> [ChildEntity] {
    @Dependencies.Dependency(\.defaultDatabase) var database
    
    let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
    
    guard !trimmed.isEmpty else { return try await suggestedEntities() }

    let children = try await database.read { db in
      try Child
        .where { $0.name.contains(trimmed) }
        .order(by: \.name)
        .fetchAll(db)
    }
    return children.map(ChildEntity.init)
  }
}

struct LogActivityIntent: AppIntent {
  static let title: LocalizedStringResource = "intent.log.activity.title"
  static let description = IntentDescription("intent.log.activity.description")

  static var parameterSummary: some ParameterSummary {
    Summary("Log \(\.$entryDescription) for \(\.$child) at \(\.$date)")
  }

  @Parameter(title: "intent.log.activity.parameter.child")
  var child: ChildEntity

  @Parameter(title: "intent.log.activity.parameter.date", default: .now)
  var date: Date

  @Parameter(title: "intent.log.activity.parameter.description")
  var entryDescription: String

  func perform() async throws -> some IntentResult {
    @Dependencies.Dependency(\.defaultDatabase) var database

    let trimmed = entryDescription
      .trimmingCharacters(in: .whitespacesAndNewlines)
    
    guard !trimmed.isEmpty else {
      throw LogActivityIntentError.missingDescription
    }

    let childID = try await database.read { db in
      try Child
        .where { $0.id.eq(child.id) }
        .fetchAll(db)
        .first?
        .id
    }
    guard let childID else { throw LogActivityIntentError.childNotFound }
    
    do {
      try await database.write { db in
        try Item
          .upsert {
            Item.Draft(childID: childID, date: date, description: trimmed)
          }
          .execute(db)
      }
    } catch {
      throw LogActivityIntentError.saveFailed
    }
    
    return .result()
  }
}

struct LogRecentActivityIntent: AppIntent {
  static let title: LocalizedStringResource = "intent.log.recent.title"
  static let description = IntentDescription("intent.log.recent.description")

  static var parameterSummary: some ParameterSummary {
    Summary("Log \(\.$entryDescription) for the most recent child")
  }

  @Parameter(title: "intent.log.activity.parameter.description")
  var entryDescription: String

  func perform() async throws -> some IntentResult {
    @Dependencies.Dependency(\.defaultDatabase) var database
    @Dependencies.Dependency(\.date.now) var now

    let trimmed = entryDescription
      .trimmingCharacters(in: .whitespacesAndNewlines)
    
    guard !trimmed.isEmpty else {
      throw LogRecentActivityIntentError.missingDescription
    }
    
    let recentChildID = try await database.read { db in
      try Item
        .order { $0.date.desc() }
        .fetchAll(db)
        .first?
        .childID
    }
    
    guard let recentChildID else {
      throw LogRecentActivityIntentError.missingRecentChild
    }
    
    do {
      let currentDate = now
      try await database.write { db in
        try Item
          .upsert {
            Item.Draft(
              childID: recentChildID,
              date: currentDate,
              description: trimmed
            )
          }
          .execute(db)
      }
    } catch {
      throw LogRecentActivityIntentError.saveFailed
    }
    
    return .result()
  }
}

struct LogActivityShortcuts: AppShortcutsProvider {
  @AppShortcutsBuilder static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: LogActivityIntent(),
      phrases: [
        "Log activity in \(.applicationName)",
        "Log activity for \(.applicationName)",
        "Log \(.applicationName)"
      ],
      shortTitle: "intent.log.activity.shortTitle",
      systemImageName: "square.and.pencil"
    )
    AppShortcut(
      intent: LogRecentActivityIntent(),
      phrases: [
        "Quick log activity in \(.applicationName)",
        "Log \(.applicationName)",
        "Quick log \(.applicationName)"
      ],
      shortTitle: "intent.log.recent.shortTitle",
      systemImageName: "square.and.pencil"
    )
  }
}

enum LogActivityIntentError: LocalizedError {
  case missingDescription
  case childNotFound
  case saveFailed

  var errorDescription: String? {
    switch self {
    case .missingDescription:
      return String(localized: "intent.log.activity.error.missingDescription")
    case .childNotFound:
      return String(localized: "intent.log.activity.error.childNotFound")
    case .saveFailed:
      return String(localized: "intent.log.activity.error.saveFailed")
    }
  }
}

enum LogRecentActivityIntentError: LocalizedError {
  case missingDescription
  case missingRecentChild
  case saveFailed

  var errorDescription: String? {
    switch self {
    case .missingDescription:
      return String(localized: "intent.log.activity.error.missingDescription")
    case .missingRecentChild:
      return String(localized: "intent.log.recent.error.missingRecentChild")
    case .saveFailed:
      return String(localized: "intent.log.activity.error.saveFailed")
    }
  }
}
