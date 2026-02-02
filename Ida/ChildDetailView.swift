import CloudKit
import SQLiteData
import SwiftUI
import SwiftUINavigation
import UserNotifications

struct ChildDetailView: View {
  @CasePathable
  enum Destination {
    case itemForm(Item.Draft)
  }
  
  @FetchAll var items: [Item]
  let child: Child
  
  private var filteredItems: [Item] {
    let trimmedSearch = searchText.trimmedForSearch
    guard !trimmedSearch.isEmpty else { return items }
    return items.filter { $0.description.fuzzyMatches(trimmedSearch) }
  }
  
  private var groupedItems: [(key: Date, value: [Item])] {
    let grouped = Dictionary(grouping: filteredItems) { $0.date.startOfDay() }
    
    return grouped
      .sorted { $0.key > $1.key } // newest day first
  }
  
  private var isFiltering: Bool {
    !searchText.trimmedForSearch.isEmpty
  }
  
  @State private var destination: Destination?
  @State private var sharedRecord: SharedRecord?
  @State private var caughtError: Error?
  @State private var isPreparingSharedRecord = false
  @State private var reminderChild: Child?
  @State private var searchText = ""
  @Dependency(\.defaultSyncEngine) var syncEngine
  @Dependency(\.defaultDatabase) var database

  init(child: Child) {
    self.child = child
    self._items = FetchAll(
      Item
        .where { $0.childID.eq(child.id) }
        .order { $0.date.desc() },
      animation: .default
    )
  }

  var body: some View {
    List {
      if let error = caughtError {
        Text(error.localizedDescription)
          .foregroundStyle(Color.white)
          .listRowBackground(Color(uiColor: .systemRed))
          .task(id: error.localizedDescription) {
            try? await Task.sleep(nanoseconds: NSEC_PER_SEC * 4)
            withAnimation { caughtError = nil }
          }
      }
      if let error = $items.loadError {
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
                destination = .itemForm(.init(item))
              } label: {
                ItemRow(item: item)
                  .buttonStyle(.borderless)
              }
            }
            .onDelete { indexSet in
              deleteRows(groupDay: group.key, at: indexSet)
            }
          }
        }
      } else if syncEngine.isLoading || $items.isLoading {
        HStack(alignment: .center) {
          ProgressView()
            .progressViewStyle(.circular)

          Text.init(.itemsLoading)
        }
        .frame(maxWidth: .infinity)
      } else if isFiltering {
        ContentUnavailableView.search(text: searchText.trimmedForSearch)
      } else {
        ContentUnavailableView(
          .childDetailEmptyTitle(child.name),
          systemImage: "figure.2.and.child.holdinghands",
          description: Text(.childDetailEmptyDescription)
        )
      }
    }
    .sheet(item: $destination.itemForm, id: \.id) {
      ItemFormSheet(itemDraft: $0)
    }
    .sheet(item: $sharedRecord) { CloudSharingView(sharedRecord: $0) }
    .sheet(item: $reminderChild) { DailyReminderSheet(child: $0) }
    .navigationTitle(child.name)
    .searchable(
      text: $searchText,
      placement: .toolbar,
      prompt: Text(.childDetailSearchPlaceholder)
    )
    .searchToolbarBehavior(.minimize)
    .toolbar {
      ToolbarItemGroup(placement: .topBarTrailing) {
        if syncEngine.isLoading || isPreparingSharedRecord {
          ProgressView()
            .progressViewStyle(.circular)
        } else {
          Button {
            shareButtonTapped()
          } label: {
            Image(systemName: "square.and.arrow.up")
          }
        }

        Button {
          reminderChild = child
        } label: {
          Image(systemName: "bell.badge")
        }
      }

      DefaultToolbarItem(kind: .search, placement: .bottomBar)

      ToolbarSpacer(.flexible, placement: .bottomBar)

      ToolbarItem(placement: .bottomBar) {
        Button {
          addButtonTapped()
        } label: {
          Image(systemName: "plus")
        }
        .buttonStyle(.glassProminent)
      }
    }
  }

  func deleteRows(groupDay: Date, at indexSet: IndexSet) {
    withErrorReporting {
      try database.write { db in
        for index in indexSet {
          guard
            let group = groupedItems.first(where: { $0.key == groupDay })
          else { continue }
          
          try Item
            .find(group.value[index].id)
            .delete()
            .execute(db)
        }
      }
    }
  }
  
  func addButtonTapped() {
    destination = .itemForm(Item.Draft(childID: child.id))
  }
  
  func shareButtonTapped() {
    Task { @MainActor in
      isPreparingSharedRecord = true
      defer { isPreparingSharedRecord = false }
      do {
        sharedRecord = try await syncEngine.share(record: child) { share in
          share[CKShare.SystemFieldKey.title] = String(localized: "child.detail.share.title \(child.name)")
          share.publicPermission = .readWrite
          share[CKShare.SystemFieldKey.thumbnailImageData] = UIImage(
            systemName: "figure.2.and.child.holdinghands"
          )?.pngData()
        }
      } catch {
        caughtError = error
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
    .presentationDetents([.medium, .large])
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
  
  func fuzzyMatches(_ query: String) -> Bool {
    let normalizedQuery = query.normalizedForSearch
    guard !normalizedQuery.isEmpty else { return true }
    let normalizedText = normalizedForSearch
    
    return normalizedQuery
      .split(whereSeparator: \.isWhitespace)
      .allSatisfy { token in
        let tokenString = String(token)
        if normalizedText.contains(tokenString) { return true }
        var tokenIndex = tokenString.startIndex
        for character in normalizedText {
          if character == tokenString[tokenIndex] {
            tokenIndex = tokenString.index(after: tokenIndex)
            if tokenIndex == tokenString.endIndex { return true }
          }
        }
        return false
      }
  }
  
  private var normalizedForSearch: String {
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
