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
  var alignment: HorizontalAlignment = .leading
  
  func sizeThatFits(
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache: inout ()
  ) -> CGSize {
    let maxWidth = proposal.width ?? .infinity
    var x: CGFloat = 0
    var y: CGFloat = 0
    var rowHeight: CGFloat = 0
    
    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)
      
      if x + size.width > maxWidth {
        // wrap to next line
        x = 0
        y += rowHeight + rowSpacing
        rowHeight = 0
      }
      
      rowHeight = max(rowHeight, size.height)
      x += size.width + spacing
    }
    
    return CGSize(
      width: maxWidth,
      height: y + rowHeight
    )
  }
  
  func placeSubviews(
    in bounds: CGRect,
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache: inout ()
  ) {
    let maxWidth = bounds.width
    var x: CGFloat = 0
    var y: CGFloat = 0
    var rowHeight: CGFloat = 0
    
    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)
      
      if x + size.width > maxWidth {
        // wrap to next line
        x = 0
        y += rowHeight + rowSpacing
        rowHeight = 0
      }
      
      let origin = CGPoint(
        x: bounds.minX + x,
        y: bounds.minY + y
      )
      
      subview.place(
        at: origin,
        proposal: ProposedViewSize(width: size.width, height: size.height)
      )
      
      rowHeight = max(rowHeight, size.height)
      x += size.width + spacing
    }
  }
}
