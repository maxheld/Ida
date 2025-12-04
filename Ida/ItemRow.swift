import SwiftUI

struct ItemRow: View {
  let item: Item

  var body: some View {
    HStack {
      Text(item.date.formatted(date: .omitted, time: .shortened))
        .foregroundColor(.secondary)
        .font(.callout)
        .monospacedDigit()
      
      Spacer()
      
      Text(item.description)
        .foregroundColor(.primary)
        .font(.default)
    }
  }
}
