import CloudKit
import SQLiteData
import SwiftUI
import SwiftUINavigation
import UserNotifications

@Observable
public final class ChildDetailModel {
  @CasePathable
  enum Destination {
    case itemForm(Item.Draft)
  }

  let child: Child
  @ObservationIgnored @FetchAll var items: [Item]

  var destination: Destination?
  var sharedRecord: SharedRecord?
  var caughtError: Error?
  var isPreparingSharedRecord = false
  var reminderChild: Child?
  var searchText = ""
  @ObservationIgnored private var normalizedDescriptionCache: [Item.ID: (source: String, normalized: String)] = [:]

  @ObservationIgnored @Dependency(\.defaultSyncEngine) var syncEngine
  @ObservationIgnored @Dependency(\.defaultDatabase) var database

  var filteredItems: [Item] {
    let trimmedSearch = searchText.trimmedForSearch
    guard !trimmedSearch.isEmpty else { return items }
    let tokens = trimmedSearch.normalizedSearchTokens
    guard !tokens.isEmpty else { return items }

    return items.filter {
      normalizedTextMatchesSearchTokens(
        normalizedDescription(for: $0),
        tokens: tokens
      )
    }
  }

  var groupedItems: [(key: Date, value: [Item])] {
    let grouped = Dictionary(grouping: filteredItems) { $0.date.startOfDay() }

    return grouped
      .sorted { $0.key > $1.key } // newest day first
  }

  var isFiltering: Bool {
    !searchText.trimmedForSearch.isEmpty
  }

  var isLoading: Bool {
    syncEngine.isLoading || $items.isLoading
  }

  public init(child: Child) {
    self.child = child
    _items = FetchAll(
      Item
        .where { $0.childID.eq(child.id) }
        .order { $0.date.desc() },
      animation: .default
    )
  }

  func itemTapped(_ item: Item) {
    destination = .itemForm(.init(item))
  }

  func deleteRows(groupDay: Date, at indexSet: IndexSet) {
    guard let group = groupedItems.first(where: { $0.key == groupDay }) else { return }
    let itemIDs: [Item.ID] = indexSet.compactMap { index in
      guard group.value.indices.contains(index) else { return nil }
      return group.value[index].id
    }
    guard !itemIDs.isEmpty else { return }

    withErrorReporting {
      try database.write { db in
        for itemID in itemIDs {
          try Item
            .find(itemID)
            .delete()
            .execute(db)
        }
      }
    }
  }

  func addButtonTapped() {
    destination = .itemForm(Item.Draft(childID: child.id))
  }

  func reminderButtonTapped() {
    reminderChild = child
  }

  func shareButtonTapped() {
    Task { @MainActor in
      isPreparingSharedRecord = true
      defer { isPreparingSharedRecord = false }
      do {
        let title = String(
          localized: "child.detail.share.title \(child.name)",
          bundle: .module
        )
        let imageData = UIImage(named: "ShareAppIcon", in: .module, with: nil)?.pngData()

        sharedRecord = try await syncEngine.share(record: child) { [title, imageData] share in
          share[CKShare.SystemFieldKey.title] = title
          share.publicPermission = .readWrite
          share[CKShare.SystemFieldKey.thumbnailImageData] = imageData
        }
      } catch {
        caughtError = error
      }
    }
  }

  private func normalizedDescription(for item: Item) -> String {
    if
      let cached = normalizedDescriptionCache[item.id],
      cached.source == item.description
    {
      return cached.normalized
    }
    let normalized = item.description.normalizedForSearch
    normalizedDescriptionCache[item.id] = (source: item.description, normalized: normalized)
    return normalized
  }

  private func normalizedTextMatchesSearchTokens(
    _ normalizedText: String,
    tokens: [Substring]
  ) -> Bool {
    tokens.allSatisfy { token in
      if normalizedText.contains(token) { return true }

      var tokenIndex = token.startIndex
      for character in normalizedText {
        if character == token[tokenIndex] {
          tokenIndex = token.index(after: tokenIndex)
          if tokenIndex == token.endIndex { return true }
        }
      }

      return false
    }
  }
}

public struct ChildDetailView: View {
  @State private var model: ChildDetailModel

  public init(child: Child) {
    _model = State(initialValue: .init(child: child))
  }

  public init(model: ChildDetailModel) {
    _model = State(initialValue: model)
  }

  public var body: some View {
    @Bindable var model = model
    let groupedItems = model.groupedItems

    List {
      if let error = model.caughtError {
        Text(error.localizedDescription)
          .foregroundStyle(Color.white)
          .listRowBackground(Color(uiColor: .systemRed))
          .task(id: error.localizedDescription) {
            try? await Task.sleep(nanoseconds: NSEC_PER_SEC * 4)
            withAnimation { model.caughtError = nil }
          }
      }
      if let error = model.$items.loadError {
        Text(error.localizedDescription)
          .foregroundStyle(Color.white)
          .listRowBackground(Color(uiColor: .systemRed))
      }
      if !groupedItems.isEmpty {
        ForEach(groupedItems, id: \.key) { group in
          Section(
            header: Text(group.key.customFormatted())
          ) {
            ForEach(group.value) { item in
              Button {
                model.itemTapped(item)
              } label: {
                ItemRow(item: item)
              }
              .buttonStyle(.borderless)
            }
            .onDelete { indexSet in
              model.deleteRows(groupDay: group.key, at: indexSet)
            }
          }
        }
      } else if model.isLoading {
        HStack(alignment: .center) {
          ProgressView()
            .progressViewStyle(.circular)

          Text.init(.itemsLoading)
        }
        .frame(maxWidth: .infinity)
      } else if model.isFiltering {
        ContentUnavailableView.search(text: model.searchText.trimmedForSearch)
      } else {
        ContentUnavailableView(
          .childDetailEmptyTitle(model.child.name),
          systemImage: "figure.2.and.child.holdinghands",
          description: Text(.childDetailEmptyDescription)
        )
      }
    }
    .sheet(item: $model.destination.itemForm, id: \.id) {
      ItemFormSheet(itemDraft: $0)
    }
    .sheet(item: $model.sharedRecord) { CloudSharingView(sharedRecord: $0) }
    .sheet(item: $model.reminderChild) { ReminderSheet(child: $0) }
    .navigationTitle(model.child.name)
    .searchable(
      text: $model.searchText,
      placement: .toolbar,
      prompt: Text(.childDetailSearchPlaceholder)
    )
    .searchToolbarBehavior(.minimize)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        if model.syncEngine.isLoading || model.isPreparingSharedRecord {
          ProgressView()
            .progressViewStyle(.circular)
        } else {
          Button {
            model.shareButtonTapped()
          } label: {
            Image(systemName: "square.and.arrow.up")
          }
        }
      }

      DefaultToolbarItem(kind: .search, placement: .topBarTrailing)

      ToolbarItemGroup(placement: .bottomBar) {
        Button {
          model.reminderButtonTapped()
        } label: {
          Image(systemName: "calendar.badge.clock")
        }

        Spacer()

        Button {
          model.addButtonTapped()
        } label: {
          Image(systemName: "plus")
        }
        .buttonStyle(.glassProminent)
      }
    }
  }
}

extension SyncEngine {
  var isLoading: Bool {
    self.isSynchronizing || self.isSendingChanges || self.isFetchingChanges
  }
}

private struct ItemFormSheet: View {
  var itemDraft: Item.Draft
  
  var body: some View {
    NavigationStack {
      ItemFormView(item: itemDraft)
        .navigationTitle(.itemFormTitle)
    }
    .presentationDetents([.large])
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

private extension String {
  var trimmedForSearch: String {
    trimmingCharacters(in: .whitespacesAndNewlines)
  }

  var normalizedSearchTokens: [Substring] {
    normalizedForSearch.split(whereSeparator: \.isWhitespace)
  }

  var normalizedForSearch: String {
    folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
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
