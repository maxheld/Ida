import Dependencies
import UserNotifications

nonisolated struct ReminderClient: Sendable {
  enum AuthorizationStatus: Sendable {
    case notDetermined
    case denied
    case authorized
  }

  var loadReminders: @Sendable (Child.ID) async -> [ScheduledReminder]
  var authorizationStatus: @Sendable () async -> AuthorizationStatus
  var requestAuthorization: @Sendable () async throws -> Bool
  var scheduleReminder: @Sendable (_ id: String?, _ child: Child, _ description: String, _ hour: Int, _ minute: Int) async throws -> Void
  var deleteReminders: @Sendable ([String]) async -> Void
}

nonisolated extension ReminderClient: DependencyKey {
  static var liveValue: ReminderClient {
    ReminderClient(
      loadReminders: { childID in
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        return requests.compactMap { request in
          ScheduledReminder(request: request, childID: childID)
        }
      },
      authorizationStatus: {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
          return .notDetermined
        case .denied:
          return .denied
        default:
          return .authorized
        }
      },
      requestAuthorization: {
        try await UNUserNotificationCenter.current()
          .requestAuthorization(options: [.alert, .sound, .badge])
      },
      scheduleReminder: { id, child, description, hour, minute in
        let center = UNUserNotificationCenter.current()
        center.registerCategories()

        let content = UNMutableNotificationContent()
        content.title = String(localized: "reminder.notification.title \(child.name)")
        content.body = String(localized: "reminder.notification.body \(description)")
        content.sound = .default
        content.categoryIdentifier = .categoryIdentifier
        content.userInfo = [
          String.userInfoChildIDKey: child.id.uuidString,
          String.userInfoDescriptionKey: description
        ]

        let trigger = UNCalendarNotificationTrigger(
          dateMatching: DateComponents(hour: hour, minute: minute),
          repeats: true
        )
        let request = UNNotificationRequest(
          identifier: id ?? UUID().uuidString,
          content: content,
          trigger: trigger
        )
        try await center.add(request)
      },
      deleteReminders: { identifiers in
        UNUserNotificationCenter.current()
          .removePendingNotificationRequests(withIdentifiers: identifiers)
      }
    )
  }

  static var testValue: ReminderClient {
    ReminderClient(
      loadReminders: { _ in [] },
      authorizationStatus: { .authorized },
      requestAuthorization: { true },
      scheduleReminder: { _, _, _, _, _ in },
      deleteReminders: { _ in }
    )
  }
}

extension DependencyValues {
  nonisolated var reminderClient: ReminderClient {
    get { self[ReminderClient.self] }
    set { self[ReminderClient.self] = newValue }
  }
}
