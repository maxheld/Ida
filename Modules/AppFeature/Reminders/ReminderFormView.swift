import SwiftUI

struct ReminderFormView: View {
  let child: Child
  let reminder: ScheduledReminder?
  let onSaved: () async -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var time = Date()
  @State private var description = ""
  @State private var isSaving = false
  @State private var errorMessage: String?
  @State private var hasSetInitialValues = false

  var body: some View {
    Form {
      Section {
        DatePicker(
          .reminderTimeLabel,
          selection: $time,
          displayedComponents: [.hourAndMinute]
        )

        TextField(.reminderDescriptionPlaceholder, text: $description)
          .textInputAutocapitalization(.sentences)
      }
    }
    .navigationTitle(reminder == nil ? .reminderAddTitle : .reminderEditTitle)
    .navigationBarTitleDisplayMode(.inline)
    .onAppear { setInitialValuesIfNeeded() }
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        if isSaving {
          ProgressView()
            .progressViewStyle(.circular)
        } else {
          Button {
            saveButtonTapped()
          } label: {
            Image(systemName: "checkmark")
          }
          .buttonStyle(.glassProminent)
          .disabled(isSaveDisabled)
        }
      }
    }
    .alert(
      String(localized: "reminder.error.title"),
      isPresented: Binding(
        get: { errorMessage != nil },
        set: { if !$0 { errorMessage = nil } }
      )
    ) {
      Button(.cancel, role: .cancel) {}
    } message: {
      Text(errorMessage ?? "")
    }
  }

  private var isSaveDisabled: Bool {
    isSaving
    || description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private func saveButtonTapped() {
    guard !isSaving else { return }
    isSaving = true
    Task {
      do {
        try await scheduleReminder()
        await onSaved()
        await MainActor.run {
          dismiss()
        }
      } catch {
        await MainActor.run {
          errorMessage = error.localizedDescription
          isSaving = false
        }
      }
    }
  }

  private func scheduleReminder() async throws {
    let center = UNUserNotificationCenter.current()
    let settings = await center.notificationSettings()
    switch settings.authorizationStatus {
    case .notDetermined:
      let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
      if !granted {
        throw ReminderError.notificationsDenied
      }
    case .denied:
      throw ReminderError.notificationsDenied
    default:
      break
    }

    UNUserNotificationCenter.current().registerCategories()

    let timeComponents = Calendar.current.dateComponents([.hour, .minute], from: time)
    let trigger = UNCalendarNotificationTrigger(
      dateMatching: DateComponents(hour: timeComponents.hour, minute: timeComponents.minute),
      repeats: true
    )

    let content = UNMutableNotificationContent()
    content.title = String(localized: "reminder.notification.title \(child.name)")
    content.body = String(localized: "reminder.notification.body \(description)")
    content.sound = .default
    content.categoryIdentifier = .categoryIdentifier
    content.userInfo = [
      String.userInfoChildIDKey: child.id.uuidString,
      String.userInfoDescriptionKey: description
    ]

    let request = UNNotificationRequest(
      identifier: reminder?.id ?? UUID().uuidString,
      content: content,
      trigger: trigger
    )
    try await center.add(request)
  }

  private func setInitialValuesIfNeeded() {
    guard !hasSetInitialValues, let reminder else { return }
    hasSetInitialValues = true
    description = reminder.description
    let calendar = Calendar.current
    let initialDate = calendar.date(
      bySettingHour: reminder.hour,
      minute: reminder.minute,
      second: 0,
      of: Date()
    )
    if let initialDate {
      time = initialDate
    }
  }
}

private enum ReminderError: LocalizedError {
  case notificationsDenied

  var errorDescription: String? {
    switch self {
    case .notificationsDenied:
      return String(localized: "reminder.error.notificationsDenied")
    }
  }
}
