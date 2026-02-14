import Dependencies
import SwiftUI

@Observable
final class ReminderFormModel {
  let child: Child
  let reminder: ScheduledReminder?

  var time = Date()
  var description = ""
  var recurrence: ReminderRecurrence = .daily {
    didSet {
      guard recurrence == .weekly else { return }
      if selectedWeekdays.isEmpty {
        selectedWeekdays = [Calendar.current.component(.weekday, from: Date())]
      }
    }
  }
  var selectedWeekdays: Set<Int> = []
  var isSaving = false
  var errorMessage: String?

  @ObservationIgnored @Dependency(\.reminderClient) var reminderClient

  init(child: Child, reminder: ScheduledReminder?) {
    self.child = child
    self.reminder = reminder
    if let reminder {
      description = reminder.description
      recurrence = reminder.recurrence
      selectedWeekdays = reminder.weekdays
      if recurrence == .weekly && selectedWeekdays.isEmpty {
        selectedWeekdays = [Calendar.current.component(.weekday, from: Date())]
      }
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
      || (recurrence == .weekly && selectedWeekdays.isEmpty)
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

  func setWeekday(_ weekday: Int, isSelected: Bool) {
    guard (1...7).contains(weekday) else { return }
    if isSelected {
      selectedWeekdays.insert(weekday)
    } else {
      selectedWeekdays.remove(weekday)
    }
  }

  private func scheduleReminder() async throws {
    switch await reminderClient.authorizationStatus() {
    case .notDetermined:
      let granted = try await reminderClient.requestAuthorization()
      if !granted {
        let message = await MainActor.run {
          String(localized: "reminder.error.notificationsDenied", bundle: .module)
        }
        throw ReminderError.notificationsDenied(message)
      }
    case .denied:
      let message = await MainActor.run {
        String(localized: "reminder.error.notificationsDenied", bundle: .module)
      }
      throw ReminderError.notificationsDenied(message)
    case .authorized:
      break
    }

    let timeComponents = Calendar.current.dateComponents([.hour, .minute], from: time)
    try await reminderClient.schedule(
      reminder?.id,
      child,
      description,
      timeComponents.hour ?? 0,
      timeComponents.minute ?? 0,
      recurrence,
      selectedWeekdays
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

      Section {
        Picker(.reminderRepeatLabel, selection: $model.recurrence) {
          ForEach(ReminderRecurrence.allCases, id: \.self) { recurrence in
            Text(recurrence.title)
              .tag(recurrence)
          }
        }
        .pickerStyle(.segmented)

        if model.recurrence == .weekly {
          ForEach(ReminderWeekday.orderedWeekdays()) { weekday in
            Toggle(
              weekday.title,
              isOn: Binding(
                get: { model.selectedWeekdays.contains(weekday.rawValue) },
                set: { model.setWeekday(weekday.rawValue, isSelected: $0) }
              )
            )
            .tint(Color.accentColor)
          }
        }
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
      String(localized: "reminder.error.title", bundle: .module),
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
  case notificationsDenied(String)

  var errorDescription: String? {
    switch self {
    case let .notificationsDenied(message):
      return message
    }
  }
}
