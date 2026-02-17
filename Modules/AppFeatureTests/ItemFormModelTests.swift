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
struct ItemFormModelTests {
  @Dependency(\.defaultDatabase) var database

  let child = Child(id: UUID(1), name: "Mila")

  @Test
  func initialState() {
    let draft = Item.Draft(
      id: UUID(2),
      childID: child.id,
      date: Date(timeIntervalSince1970: 1_700_000_000),
      description: ""
    )
    let model = ItemFormModel(item: draft)

    expectNoDifference(model.item.id, draft.id)
    expectNoDifference(model.item.childID, draft.childID)
    expectNoDifference(model.item.date, draft.date)
    expectNoDifference(model.item.description, draft.description)
    expectNoDifference(model.suggestions.map(\.description), [])
    expectNoDifference(model.emojiSuggestions.map(\.description), [])
    expectNoDifference(model.frequentlyUsedEmojis, [])
  }

  @Test
  func itemFormAutofocusSettingDefaultsToEnabled() {
    let model = ItemFormModel(item: .init(childID: child.id))

    expectNoDifference(model.isItemFormAutofocusEnabled, true)
  }

  @Test
  func itemFormAutofocusSettingPersistsAcrossModels() {
    let firstModel = ItemFormModel(item: .init(childID: child.id))
    let secondModel = ItemFormModel(item: .init(childID: child.id))

    expectNoDifference(firstModel.isItemFormAutofocusEnabled, true)
    expectNoDifference(secondModel.isItemFormAutofocusEnabled, true)

    firstModel.$isItemFormAutofocusEnabled.withLock { $0 = false }

    expectNoDifference(firstModel.isItemFormAutofocusEnabled, false)
    expectNoDifference(secondModel.isItemFormAutofocusEnabled, false)
  }

  @Test
  func itemFormSuggestionsSettingDefaultsToEnabled() {
    let model = ItemFormModel(item: .init(childID: child.id))

    expectNoDifference(model.isItemFormSuggestionsEnabled, true)
  }

  @Test
  func itemFormSuggestionsSettingPersistsAcrossModels() {
    let firstModel = ItemFormModel(item: .init(childID: child.id))
    let secondModel = ItemFormModel(item: .init(childID: child.id))

    expectNoDifference(firstModel.isItemFormSuggestionsEnabled, true)
    expectNoDifference(secondModel.isItemFormSuggestionsEnabled, true)

    firstModel.$isItemFormSuggestionsEnabled.withLock { $0 = false }

    expectNoDifference(firstModel.isItemFormSuggestionsEnabled, false)
    expectNoDifference(secondModel.isItemFormSuggestionsEnabled, false)
  }

  @Test
  func itemFormEmojiSuggestionsSettingDefaultsToEnabled() {
    let model = ItemFormModel(item: .init(childID: child.id))

    expectNoDifference(model.isItemFormEmojiSuggestionsEnabled, true)
  }

  @Test
  func itemFormEmojiSuggestionsSettingPersistsAcrossModels() {
    let firstModel = ItemFormModel(item: .init(childID: child.id))
    let secondModel = ItemFormModel(item: .init(childID: child.id))

    expectNoDifference(firstModel.isItemFormEmojiSuggestionsEnabled, true)
    expectNoDifference(secondModel.isItemFormEmojiSuggestionsEnabled, true)

    firstModel.$isItemFormEmojiSuggestionsEnabled.withLock { $0 = false }

    expectNoDifference(firstModel.isItemFormEmojiSuggestionsEnabled, false)
    expectNoDifference(secondModel.isItemFormEmojiSuggestionsEnabled, false)
  }

  @Test
  func suggestionButtonTappedSetsDescription() {
    let model = ItemFormModel(item: .init(childID: child.id, description: "Old"))

    model.suggestionButtonTapped(.init(description: "New suggestion"))

    expectNoDifference(model.item.description, "New suggestion")
  }

  @Test
  func emojiButtonTappedBuildsDescription() {
    let model = ItemFormModel(item: .init(childID: child.id, description: "Milk"))

    model.emojiButtonTapped("😄")
    model.emojiButtonTapped("🍎")

    expectNoDifference(model.item.description, "Milk 😄 🍎")
  }

  @Test
  func saveButtonTappedUpsertsItem() throws {
    try insertChild(child)
    let draft = Item.Draft(
      id: UUID(3),
      childID: child.id,
      date: Date(timeIntervalSince1970: 1_700_100_000),
      description: "Snack time"
    )
    let model = ItemFormModel(item: draft)

    model.saveButtonTapped()

    let items = try database.read { db in
      try Item
        .where { $0.childID.eq(child.id) }
        .order { $0.date.desc() }
        .fetchAll(db)
    }
    expectNoDifference(items.map(\.id), [draft.id])
    expectNoDifference(items.map(\.description), ["Snack time"])
  }

  @Test
  func loadSuggestionsTaskFiltersByCurrentDescription() async throws {
    try insertChild(child)
    try insertItems([
      Item(
        id: UUID(10),
        childID: child.id,
        date: Date(timeIntervalSince1970: 1_700_100_000),
        description: "Milk bottle"
      ),
      Item(
        id: UUID(11),
        childID: child.id,
        date: Date(timeIntervalSince1970: 1_700_000_000),
        description: "Nap"
      ),
    ])
    let model = ItemFormModel(item: .init(childID: child.id, description: "Milk"))

    await model.loadSuggestionsTask()

    expectNoDifference(model.suggestions.map(\.description), ["Milk bottle"])
  }

  @Test
  func loadSuggestionsTaskLimitsResults() async throws {
    try insertChild(child)
    try insertItems(
      (0..<20).map { index in
        Item(
          id: UUID(100 + index),
          childID: child.id,
          date: Date(timeIntervalSince1970: 1_700_200_000 - Double(index)),
          description: "Milk \(index)"
        )
      }
    )
    let model = ItemFormModel(item: .init(childID: child.id, description: "Milk"))

    await model.loadSuggestionsTask()

    expectNoDifference(model.suggestions.count, ItemFormModel.suggestionsLimit)
    expectNoDifference(model.suggestions.first?.description, "Milk 0")
    expectNoDifference(model.suggestions.last?.description, "Milk 11")
  }

  @Test
  func loadSuggestionsTaskSkipsQueryWhenSuggestionsDisabled() async throws {
    try insertChild(child)
    try insertItems([
      Item(
        id: UUID(120),
        childID: child.id,
        date: Date(timeIntervalSince1970: 1_700_210_000),
        description: "Milk bottle"
      )
    ])
    let model = ItemFormModel(item: .init(childID: child.id, description: "Milk"))
    model.$isItemFormSuggestionsEnabled.withLock { $0 = false }

    await model.loadSuggestionsTask()

    expectNoDifference(model.suggestions.map(\.description), [])
  }

  @Test
  func loadEmojiSuggestionsTaskCalculatesFrequency() async throws {
    try insertChild(child)
    try insertItems([
      Item(
        id: UUID(20),
        childID: child.id,
        date: Date(timeIntervalSince1970: 1_700_100_000),
        description: "😄😄"
      ),
      Item(
        id: UUID(21),
        childID: child.id,
        date: Date(timeIntervalSince1970: 1_700_000_000),
        description: "🍎😄"
      ),
    ])
    let model = ItemFormModel(item: .init(childID: child.id))

    await model.loadEmojiSuggestionsTask()

    expectNoDifference(model.frequentlyUsedEmojis, ["😄", "🍎"])
  }

  @Test
  func loadEmojiSuggestionsTaskLimitsDisplayedEmojis() async throws {
    let emojis = [
      "😀", "😁", "😂", "😃", "😄",
      "😅", "😆", "😉", "😊", "😋",
      "😎", "😍", "😘", "😗", "😙",
      "😚", "😇", "🙂", "🙃", "😌",
    ]

    try insertChild(child)
    try insertItems([
      Item(
        id: UUID(300),
        childID: child.id,
        date: Date(timeIntervalSince1970: 1_700_300_000),
        description: emojis.joined()
      )
    ])
    let model = ItemFormModel(item: .init(childID: child.id))

    await model.loadEmojiSuggestionsTask()

    expectNoDifference(model.frequentlyUsedEmojis.count, ItemFormModel.emojiDisplayLimit)
    expectNoDifference(
      model.frequentlyUsedEmojis,
      Array(emojis.prefix(ItemFormModel.emojiDisplayLimit))
    )
  }

  @Test
  func loadEmojiSuggestionsTaskSkipsQueryWhenDisabled() async throws {
    try insertChild(child)
    try insertItems([
      Item(
        id: UUID(320),
        childID: child.id,
        date: Date(timeIntervalSince1970: 1_700_310_000),
        description: "😄🍎"
      )
    ])
    let model = ItemFormModel(item: .init(childID: child.id))
    model.$isItemFormEmojiSuggestionsEnabled.withLock { $0 = false }

    await model.loadEmojiSuggestionsTask()

    expectNoDifference(model.emojiSuggestions.map(\.description), [])
    expectNoDifference(model.frequentlyUsedEmojis, [])
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
