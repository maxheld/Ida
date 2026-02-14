import Dependencies
import SwiftUI

@Observable
final class ReminderSheetModel {
  let child: Child
  var reminders: [ScheduledReminder] = []
  var isLoading = false

  @ObservationIgnored @Dependency(\.reminderClient) var reminderClient

  init(child: Child) {
    self.child = child
  }

  func loadRemindersTask() async {
    guard !isLoading else { return }
    isLoading = true
    defer { isLoading = false }

    reminders = await reminderClient
      .loadReminders(child.id)
      .sorted { $0.sortKey < $1.sortKey }
  }

  func deleteReminders(at offsets: IndexSet) async {
    let identifiers = offsets.flatMap { reminders[$0].requestIDs }
    await reminderClient.deleteReminders(identifiers)
    await loadRemindersTask()
  }
}

struct ReminderSheet: View {
  @Environment(\.dismiss) private var dismiss
  @State private var model: ReminderSheetModel

  init(child: Child) {
    _model = State(initialValue: .init(child: child))
  }

  init(model: ReminderSheetModel) {
    _model = State(initialValue: model)
  }

  var body: some View {
    NavigationStack {
      Group {
        if model.reminders.isEmpty {
          ContentUnavailableView(
            .reminderListEmptyTitle,
            systemImage: "bell",
            description: Text(.reminderListEmptyDescription)
          )
        } else {
          List {
            ForEach(model.reminders) { reminder in
              NavigationLink {
                ReminderFormView(child: model.child, reminder: reminder) {
                  await model.loadRemindersTask()
                }
              } label: {
                HStack(alignment: .firstTextBaseline) {
                  Image(systemName: "circle")
                    .foregroundStyle(.secondary)

                  VStack(alignment: .leading, spacing: 2) {
                    Text("\(reminder.timeText) • \(reminder.recurrenceText)")
                      .font(.body)
                      .foregroundStyle(.primary)

                    Text(reminder.description)
                      .font(.body)
                      .multilineTextAlignment(.leading)
                      .foregroundStyle(.secondary)
                      .lineLimit(4)
                  }
                }
              }
            }
            .onDelete { offsets in
              Task { await model.deleteReminders(at: offsets) }
            }
          }
          .listStyle(.insetGrouped)
        }
      }
      .navigationTitle(.reminderSheetTitle)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          NavigationLink {
            ReminderFormView(child: model.child, reminder: nil) {
              await model.loadRemindersTask()
            }
          } label: {
            Image(systemName: "plus")
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
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
    .task { await model.loadRemindersTask() }
  }
}
