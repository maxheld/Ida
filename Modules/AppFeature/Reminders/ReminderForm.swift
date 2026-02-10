import Dependencies
import SwiftUI

@Observable
final class ReminderFormModel {
  let child: Child
  let reminder: ScheduledReminder?

  var time = Date()
  var description = ""
  var isSaving = false
  var errorMessage: String?

  @ObservationIgnored @Dependency(\.reminderClient) var reminderClient

  init(child: Child, reminder: ScheduledReminder?) {
    self.child = child
    self.reminder = reminder
    if let reminder {
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

  var isSaveDisabled: Bool {
    isSaving
      || description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  func saveButtonTapped() async -> Bool {
    guard !isSaving else { return false }
    isSaving = true
    defer { isSaving = false }

    do {
      try await scheduleReminder()
      return true
    } catch {
      errorMessage = error.localizedDescription
      return false
    }
  }

  func alertDismissed() {
    errorMessage = nil
  }

  private func scheduleReminder() async throws {
    switch await reminderClient.authorizationStatus() {
    case .notDetermined:
      let granted = try await reminderClient.requestAuthorization()
      if !granted {
        throw ReminderError.notificationsDenied
      }
    case .denied:
      throw ReminderError.notificationsDenied
    case .authorized:
      break
    }

    let timeComponents = Calendar.current.dateComponents([.hour, .minute], from: time)
    try await reminderClient.scheduleReminder(
      reminder?.id,
      child,
      description,
      timeComponents.hour ?? 0,
      timeComponents.minute ?? 0
    )
  }
}

struct ReminderFormView: View {
  let onSaved: () async -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var model: ReminderFormModel

  init(
    child: Child,
    reminder: ScheduledReminder?,
    onSaved: @escaping () async -> Void
  ) {
    _model = State(initialValue: .init(child: child, reminder: reminder))
    self.onSaved = onSaved
  }

  init(
    model: ReminderFormModel,
    onSaved: @escaping () async -> Void = {}
  ) {
    _model = State(initialValue: model)
    self.onSaved = onSaved
  }

  var body: some View {
    @Bindable var model = model

    Form {
      Section {
        DatePicker(
          .reminderTimeLabel,
          selection: $model.time,
          displayedComponents: [.hourAndMinute]
        )

        TextField(.reminderDescriptionPlaceholder, text: $model.description)
          .textInputAutocapitalization(.sentences)
      }
    }
    .navigationTitle(model.reminder == nil ? .reminderAddTitle : .reminderEditTitle)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        if model.isSaving {
          ProgressView()
            .progressViewStyle(.circular)
        } else {
          Button {
            Task {
              if await model.saveButtonTapped() {
                await onSaved()
                dismiss()
              }
            }
          } label: {
            Image(systemName: "checkmark")
          }
          .buttonStyle(.glassProminent)
          .disabled(model.isSaveDisabled)
        }
      }
    }
    .alert(
      String(localized: "reminder.error.title"),
      isPresented: Binding(
        get: { model.errorMessage != nil },
        set: { if !$0 { model.alertDismissed() } }
      )
    ) {
      Button(.cancel, role: .cancel) {}
    } message: {
      Text(model.errorMessage ?? "")
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
