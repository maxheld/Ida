import CloudKit
import SQLiteData
import Sharing
import SwiftUI
import SwiftUINavigation

@Selection
struct Suggestion: Identifiable {
  let description: String
  
  var id: String { description }
}

enum Field: Hashable {
  case description
}

@Observable
final class ItemFormModel {
  static let suggestionsLimit = 12
  static let emojiHistoryLimit = 250
  static let emojiDisplayLimit = 16

  var item: Item.Draft
  @ObservationIgnored @FetchAll(Suggestion.none) var suggestions: [Suggestion]
  @ObservationIgnored @FetchAll(Suggestion.none) var emojiSuggestions: [Suggestion]
  var frequentlyUsedEmojis: [String] = []
  @ObservationIgnored @Shared(.isItemFormAutofocusEnabled) var isItemFormAutofocusEnabled: Bool

  @ObservationIgnored @Dependency(\.defaultDatabase) private var database

  init(item: Item.Draft) {
    self.item = item
  }

  func saveButtonTapped() {
    withErrorReporting {
      try database.write { db in
        try Item.upsert { item }.execute(db)
      }
    }
  }

  func suggestionButtonTapped(_ suggestion: Suggestion) {
    item.description = suggestion.description
  }

  func emojiButtonTapped(_ emoji: String) {
    if item.description != "" {
      item.description.append(" \(emoji)")
    } else {
      item.description = emoji
    }
  }

  func loadSuggestionsTask() async {
    await loadSuggestionsTask(searchText: item.description)
  }

  func loadSuggestionsDebouncedTask(for searchText: String) async {
    do {
      try await Task.sleep(nanoseconds: 250_000_000)
    } catch {
      return
    }
    guard !Task.isCancelled else { return }
    await loadSuggestionsTask(searchText: searchText)
  }

  private func loadSuggestionsTask(searchText: String) async {
    let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

    _ = await withErrorReporting {
      try await $suggestions.load(
        Item
          .where { $0.childID.eq(item.childID) }
          .where {
            if !trimmedSearch.isEmpty {
              $0.description.contains(trimmedSearch)
            } else {
              true
            }
          }
          .order { $0.date.desc() }
          .distinct()
          .limit(Self.suggestionsLimit)
          .select { Suggestion.Columns(description: $0.description) },
        animation: .default
      )
    }
  }

  func loadEmojiSuggestionsTask() async {
    _ = await withErrorReporting {
      try await $emojiSuggestions.load(
        Item
          .where { $0.childID.eq(item.childID) }
          .order { $0.date.desc() }
          .limit(Self.emojiHistoryLimit)
          .select { Suggestion.Columns(description: $0.description) },
        animation: .default
      )
    }
    frequentlyUsedEmojis = Array(
      uniqueEmojisByFrequency(in: emojiSuggestions.map(\.description))
        .prefix(Self.emojiDisplayLimit)
    )
  }
}

struct ItemFormView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var model: ItemFormModel

  @FocusState private var focus: Field?

  init(item: Item.Draft) {
    _model = State(initialValue: .init(item: item))
  }

  init(model: ItemFormModel) {
    _model = State(initialValue: model)
  }
  
  var body: some View {
    @Bindable var model = model

    Form {
      Section {
        DatePicker(
          .itemFormDatepickerLabel,
          selection: $model.item.date,
          displayedComponents: [.date, .hourAndMinute]
        )
        .labelsHidden()
        
        TimeShortcuts(date: $model.item.date)
      }
      
      Section {
        TextField(.itemFormTextfieldLabel, text: $model.item.description)
          .focused($focus, equals: .description)
          .padding(4)
          .onAppear {
            guard model.isItemFormAutofocusEnabled else { return }
            focus = .description
          }
      }
      if !model.suggestions.isEmpty {
        Section {
          FlowLayout {
            ForEach(model.suggestions) { suggestion in
              Button(suggestion.description) {
                model.suggestionButtonTapped(suggestion)
              }
              .multilineTextAlignment(.leading)
              .lineLimit(nil)
            }
            .buttonStyle(.glass)
          }
          .listRowBackground(Color.clear)
          .listRowInsets(.horizontal, 4)
        }
        .listSectionSpacing(.custom(0))
      }
    }
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button {
          model.saveButtonTapped()
          dismiss()
        } label: {
          Image(systemName: "checkmark")
        }
        .buttonStyle(.glassProminent)
        .disabled(model.item.description == "")
      }

      ToolbarItemGroup(placement: .keyboard) {
        if !model.frequentlyUsedEmojis.isEmpty {
          ScrollView(.horizontal, showsIndicators: false) {
            HStack {
              ForEach(model.frequentlyUsedEmojis, id: \.self) { emoji in
                Button(emoji) {
                  model.emojiButtonTapped(emoji)
                }
                .padding(.horizontal, 8)
                .buttonStyle(.plain)
              }
            }
          }
        }
      }

      ToolbarItem(placement: .cancellationAction) {
        Button {
          dismiss()
        } label: {
          Image(systemName: "xmark")
        }
      }
    }
    .task(id: model.item.description) {
      await model.loadSuggestionsDebouncedTask(for: model.item.description)
    }
    .task { await model.loadEmojiSuggestionsTask() }
  }
}

private struct TimeShortcuts: View {
  @Binding var date: Date
  
  var body: some View {
    HStack(alignment: .center) {
      Button {
        date.addTimeInterval(-10 * 60)
      } label: {
        Image(systemName: "10.arrow.trianglehead.clockwise")
      }
      Spacer()
      Button {
        date.addTimeInterval(-5 * 60)
      } label: {
        Image(systemName: "5.arrow.trianglehead.clockwise")
      }
      Spacer()
      Button {
        date.addTimeInterval(-1 * 60)
      } label: {
        Image(systemName: "minus.arrow.trianglehead.clockwise")
      }
      Spacer()
      Button {
        date.addTimeInterval(1 * 60)
      } label: {
        Image(systemName: "plus.arrow.trianglehead.counterclockwise")
      }
      Spacer()
      Button {
        date.addTimeInterval(5 * 60)
      } label: {
        Image(systemName: "5.arrow.trianglehead.counterclockwise")
      }
      Spacer()
      Button {
        date.addTimeInterval(10 * 60)
      } label: {
        Image(systemName: "10.arrow.trianglehead.counterclockwise")
      }
    }
    .buttonStyle(.glass)
  }
}

private struct FlowLayout: Layout {
  var spacing: CGFloat = 4
  var rowSpacing: CGFloat = 4
  
  struct Cache {
    var frames: [CGRect] = []
    var size: CGSize = .zero
  }
  
  func makeCache(subviews: Subviews) -> Cache {
    Cache(frames: Array(repeating: .zero, count: subviews.count))
  }
  
  func updateCache(_ cache: inout Cache, subviews: Subviews) {
    if cache.frames.count != subviews.count {
      cache.frames = Array(repeating: .zero, count: subviews.count)
    }
  }
  
  func sizeThatFits(
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache: inout Cache
  ) -> CGSize {
    updateCache(&cache, subviews: subviews)
    
    // If parent doesn't propose a width, don't force wrapping (we'll compute natural width).
    let proposedWidth = proposal.width
    let maxWidth = proposedWidth ?? .greatestFiniteMagnitude
    
    var x: CGFloat = 0
    var y: CGFloat = 0
    var rowHeight: CGFloat = 0
    var usedWidth: CGFloat = 0
    
    func measure(_ subview: Subviews.Element, constrainedTo width: CGFloat) -> CGSize {
      // First try "ideal"
      var size = subview.sizeThatFits(.unspecified)
      
      // If it doesn't fit, propose a width so Text inside can wrap.
      if size.width > width {
        size = subview.sizeThatFits(ProposedViewSize(width: width, height: proposal.height))
        size.width = min(size.width, width)
      }
      
      return size
    }
    
    for index in subviews.indices {
      // Remaining space in current row; if we're at row start, it's full width.
      let remaining = maxWidth - x
      var size = measure(subviews[index], constrainedTo: maxWidth)
      
      // If it doesn't fit in remaining space, move to next row.
      if x > 0, size.width > remaining {
        x = 0
        y += rowHeight + rowSpacing
        rowHeight = 0
        
        // Re-measure for the new row (full width available).
        size = measure(subviews[index], constrainedTo: maxWidth)
      }
      
      cache.frames[index] = CGRect(x: x, y: y, width: size.width, height: size.height)
      
      x += size.width + spacing
      rowHeight = max(rowHeight, size.height)
      
      usedWidth = max(usedWidth, x == 0 ? 0 : (x - spacing))
    }
    
    let totalHeight = subviews.isEmpty ? 0 : (y + rowHeight)
    let finalWidth = proposedWidth ?? usedWidth
    
    cache.size = CGSize(width: finalWidth, height: totalHeight)
    return cache.size
  }
  
  func placeSubviews(
    in bounds: CGRect,
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache: inout Cache
  ) {
    // Ensure frames are computed for the current proposal.
    _ = sizeThatFits(proposal: proposal, subviews: subviews, cache: &cache)
    
    for index in subviews.indices {
      let frame = cache.frames[index].offsetBy(dx: bounds.minX, dy: bounds.minY)
      subviews[index].place(
        at: frame.origin,
        proposal: ProposedViewSize(width: frame.width, height: frame.height)
      )
    }
  }
}

// MARK: Private helpers

extension Character {
  /// Heuristic emoji detection for single-scalar and multi-scalar emoji grapheme clusters.
  var isEmoji: Bool {
    guard let firstScalar = unicodeScalars.first else { return false }
    
    let containsEmojiScalar = unicodeScalars.contains { $0.properties.isEmoji }
    if !containsEmojiScalar { return false }
    
    return unicodeScalars.count > 1
    || firstScalar.properties.isEmojiPresentation
    || firstScalar.value > 0x238C
  }
}

/// Returns unique emojis sorted by frequency (highest first) across multiple strings.
/// Tie-breaker: first time the emoji appeared across all inputs (earlier first).
func uniqueEmojisByFrequency(in texts: [String]) -> [String] {
  var counts: [String: Int] = [:]
  var firstSeenIndex: [String: Int] = [:]
  var nextIndex = 0
  
  for text in texts {
    for character in text where character.isEmoji {
      let emoji = String(character)
      counts[emoji, default: 0] += 1
      
      if firstSeenIndex[emoji] == nil {
        firstSeenIndex[emoji] = nextIndex
        nextIndex += 1
      }
    }
  }
  
  return counts.keys.sorted { a, b in
    let ca = counts[a, default: 0]
    let cb = counts[b, default: 0]
    if ca != cb { return ca > cb } // most frequent first
    
    // deterministic tie-breaker: earlier first appearance
    return (firstSeenIndex[a] ?? Int.max) < (firstSeenIndex[b] ?? Int.max)
  }
}

/// Variadic convenience overload.
func uniqueEmojisByFrequency(_ texts: String...) -> [String] {
  uniqueEmojisByFrequency(in: texts)
}
