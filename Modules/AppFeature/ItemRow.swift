import SwiftUI

struct ItemRow: View {
  let item: Item

  var body: some View {
    HStack(alignment: .firstTextBaseline) {
      Text(
        item.date,
        format: .dateTime
          .hour(.twoDigits(amPM: .abbreviated))
          .minute(.twoDigits)
      )
      .foregroundColor(.secondary)
      .font(.callout)
      .monospacedDigit()

      HStack {
        Text(item.description)
          .multilineTextAlignment(.leading)
          .foregroundColor(.primary)
          .font(.default)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
      .padding(.horizontal, 8)
    }
  }
}
