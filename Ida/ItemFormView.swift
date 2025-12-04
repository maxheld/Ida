import CloudKit
import SQLiteData
import SwiftUI
import SwiftUINavigation

struct ItemFormView: View {
  @Dependency(\.defaultDatabase) private var database
  @Environment(\.dismiss) private var dismiss

  @State var item: Item.Draft
  
  var body: some View {
    Form {
      Section {
        DatePicker(
          "Select time",
          selection: $item.date,
          displayedComponents: [.date, .hourAndMinute]
        )
        .labelsHidden()
      }
      
      Section {
        TextField("Description", text: $item.description)
          .textFieldStyle(.plain)
          .padding()
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
      }
      ToolbarItem(placement: .cancellationAction) {
        Button {
          dismiss()
        } label: {
          Image(systemName: "xmark")
        }
      }
    }
  }
  
  private func saveButtonTapped() {
    withErrorReporting {
      try database.write { db in
        try Item.upsert { item }.execute(db)
      }
    }
    dismiss()
  }
}
