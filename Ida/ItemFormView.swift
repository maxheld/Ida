import CloudKit
import SQLiteData
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

struct ItemFormView: View {
  @Dependency(\.defaultDatabase) private var database
  @Environment(\.dismiss) private var dismiss

  @State var item: Item.Draft
  @FocusState private var focus: Field?
  
  @FetchAll(Suggestion.none) var suggestions: [Suggestion]
  
  var body: some View {
    Form {
      Section {
        DatePicker(
          .itemFormDatepickerLabel,
          selection: $item.date,
          displayedComponents: [.date, .hourAndMinute]
        )
        .labelsHidden()
        
        TimeShortcuts(date: $item.date)
      }
      
      Section {
        TextField(.itemFormTextfieldLabel, text: $item.description)
          .focused($focus, equals: .description)
          .padding()
          .onAppear { focus = .description }
        
        if !suggestions.isEmpty {
          FlowLayout {
            ForEach(suggestions) { suggestion in
              Button(suggestion.description) {
                item.description = suggestion.description
              }
              .multilineTextAlignment(.leading)
              .lineLimit(nil)
            }
            .buttonStyle(.bordered)
          }
        }
      }
    }
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button {
          saveButtonTapped()
        } label: {
          Image(systemName: "checkmark")
        }
        .buttonStyle(.glassProminent)
        .disabled(item.description == "")
      }
      ToolbarItem(placement: .cancellationAction) {
        Button {
          dismiss()
        } label: {
          Image(systemName: "xmark")
        }
      }
    }
    .task(id: item.description) { await task() }
  }
  
  private func saveButtonTapped() {
    withErrorReporting {
      try database.write { db in
        try Item.upsert { item }.execute(db)
      }
    }
    dismiss()
  }
  
  private func task() async {
    _ = await withErrorReporting {
      try await $suggestions.load(
        Item
          .where { $0.childID.eq(item.childID) }
          .where {
            if item.description != "" {
              $0.description.contains(item.description)
            } else {
              true
            }
          }
          .order { $0.date.desc() }
          .distinct()
          .select { Suggestion.Columns(description: $0.description) }
      )
    }
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
