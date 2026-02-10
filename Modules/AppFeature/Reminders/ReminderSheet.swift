import Dependencies
import SwiftUI

struct DailyReminderSheet: View {
  let child: Child

  @Environment(\.dismiss) private var dismiss
  @Dependency(\.notificationCenter) var notificationCenter
  @State private var reminders: [ScheduledReminder] = []
  @State private var isLoading = false

  var body: some View {
    NavigationStack {
      Group {
        if reminders.isEmpty {
          ContentUnavailableView(
            .reminderListEmptyTitle,
            systemImage: "bell",
            description: Text(.reminderListEmptyDescription)
          )
        } else {
          List {
            ForEach(reminders) { reminder in
              NavigationLink {
                ReminderFormView(child: child, reminder: reminder) {
                  await loadReminders()
                }
              } label: {
                HStack(alignment: .firstTextBaseline) {
                  Image(systemName: "circle")
                    .foregroundStyle(.secondary)

                  Text(reminder.timeText)
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
            .onDelete(perform: deleteReminders)
          }
          .listStyle(.insetGrouped)
        }
      }
      .navigationTitle(.reminderSheetTitle)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          NavigationLink {
            ReminderFormView(child: child, reminder: nil) {
              await loadReminders()
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
    .task { await loadReminders() }
  }

  private func loadReminders() async {
    guard !isLoading else { return }
    isLoading = true
    defer { isLoading = false }
    let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
    let filtered = requests.compactMap { request in
      ScheduledReminder(request: request, childID: child.id)
    }
    reminders = filtered.sorted { lhs, rhs in
      lhs.sortKey < rhs.sortKey
    }
  }

  private func deleteReminders(at offsets: IndexSet) {
    let identifiers = offsets.map { reminders[$0].id }
    UNUserNotificationCenter.current()
      .removePendingNotificationRequests(withIdentifiers: identifiers)
    Task { await loadReminders() }
  }
}
