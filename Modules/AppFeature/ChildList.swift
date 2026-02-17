import SQLiteData
import SwiftUI

@Observable
public final class ChildListModel {
  @Selection struct Row: Identifiable {
    var id: UUID { child.id }
    let child: Child
    let isShared: Bool
  }

  @ObservationIgnored @FetchAll var rows: [Row]

  var isNewChildAlertPresented = false
  var newChildName = ""

  @ObservationIgnored @Dependency(\.defaultDatabase) var database

  public init() {
    _rows = FetchAll(
      Child
        .order(by: \.name)
        .leftJoin(SyncMetadata.all) { $0.syncMetadataID.eq($1.id) }
        .select {
          Row.Columns(child: $0, isShared: $1.isShared.ifnull(false))
        },
      animation: .default
    )
  }

  func addButtonTapped() {
    newChildName = ""
    isNewChildAlertPresented = true
  }

  func saveButtonTapped() {
    withErrorReporting {
      try database.write { db in
        try Child
          .upsert { Child.Draft(name: newChildName) }
          .execute(db)
      }
    }
  }

  func deleteRows(at indexSet: IndexSet) {
    withErrorReporting {
      try database.write { db in
        for index in indexSet {
          try Child
            .find(rows[index].child.id)
            .delete()
            .execute(db)
        }
      }
    }
  }
}

public struct ChildListView: View {
  @ScaledMetric(relativeTo: .body) private var textSize: CGFloat = 20
  @State private var model: ChildListModel

  public init(model: ChildListModel = .init()) {
    _model = State(initialValue: model)
  }

  public var body: some View {
    @Bindable var model = model

    List {
      if !model.rows.isEmpty {
        ForEach(model.rows) { row in
          NavigationLink {
            ChildDetailView(child: row.child)
          } label: {
            HStack {
              if row.isShared {
                Image(systemName: "checkmark.icloud.fill")
                  .foregroundStyle(Color.accentColor)
              }

              Text(row.child.name)
                .font(.system(size: textSize))
            }
            .padding(4)
          }
        }
        .onDelete { indexSet in
          model.deleteRows(at: indexSet)
        }
      } else {
        ContentUnavailableView(
          .childListEmptyTitle,
          systemImage: "figure.2.and.child.holdinghands",
          description: Text(.childListEmptyDescription)
        )
      }
    }
    .navigationTitle(.childListTitle)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        NavigationLink {
          SettingsView()
        } label: {
          Image(systemName: "gearshape")
        }
        .accessibilityLabel(
          Text(
            LocalizedStringResource("settings.title", bundle: .module)
          )
        )
      }

      ToolbarSpacer(.fixed, placement: .topBarTrailing)

      ToolbarItemGroup(placement: .topBarTrailing) {
        NavigationLink {
          AboutView()
        } label: {
          Image(systemName: "info.circle")
        }
        .accessibilityLabel(
          Text(
            LocalizedStringResource("about.privacy.title", bundle: .module)
          )
        )
      }

      ToolbarItemGroup(placement: .bottomBar) {
        Spacer()

        Button {
          model.addButtonTapped()
        } label: {
          Image(systemName: "plus")
        }
        .alert(
          .childListNewChildTitle,
          isPresented: $model.isNewChildAlertPresented
        ) {
          TextField(.childListNewChildNameLabel, text: $model.newChildName)

          Button(.save) {
            model.saveButtonTapped()
          }
          .disabled(model.newChildName.isEmpty)

          Button(.cancel, role: .cancel) { }
        }
      }
    }
  }
}

#Preview {
  let _ = try! prepareDependencies {
    try $0.bootstrapDatabase(seedData: true)
  }
  NavigationStack {
    ChildListView()
  }
}
