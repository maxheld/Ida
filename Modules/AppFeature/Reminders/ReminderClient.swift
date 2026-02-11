import Dependencies
import UserNotifications

nonisolated struct ReminderClient: Sendable {
  typealias ScheduleRecurringReminder = @Sendable (
    _ id: String?,
    _ child: Child,
    _ description: String,
    _ hour: Int,
    _ minute: Int,
    _ recurrence: ReminderRecurrence,
    _ weekdays: Set<Int>
  ) async throws -> Void

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
  var scheduleRecurringReminder: ScheduleRecurringReminder? = nil

  func schedule(
    _ id: String?,
    _ child: Child,
    _ description: String,
    _ hour: Int,
    _ minute: Int,
    _ recurrence: ReminderRecurrence,
    _ weekdays: Set<Int>
  ) async throws {
    if let scheduleRecurringReminder {
      try await scheduleRecurringReminder(
        id,
        child,
        description,
        hour,
        minute,
        recurrence,
        weekdays
      )
      return
    }

    try await scheduleReminder(id, child, description, hour, minute)
  }
}

nonisolated extension ReminderClient: DependencyKey {
  static var liveValue: ReminderClient {
    let scheduleRecurring: ReminderClient.ScheduleRecurringReminder = {
      id,
      child,
      description,
      hour,
      minute,
      recurrence,
      weekdays in
      let center = UNUserNotificationCenter.current()
      await MainActor.run { UNUserNotificationCenter.current().registerCategories() }

      let seriesID = id ?? UUID().uuidString
      let normalizedWeekdays = Set(weekdays.filter { (1...7).contains($0) })
      let requestedWeekdays: [Int]
      switch recurrence {
      case .daily:
        requestedWeekdays = []
      case .weekly:
        let sortedWeekdays = normalizedWeekdays.sorted()
        if sortedWeekdays.isEmpty {
          requestedWeekdays = [Calendar.current.component(.weekday, from: Date())]
        } else {
          requestedWeekdays = sortedWeekdays
        }
      }

      let existingRequests = await center.pendingNotificationRequests()
      let existingIdentifiers = existingRequests.compactMap { request -> String? in
        guard request.content.categoryIdentifier == .categoryIdentifier else { return nil }
        guard request.content.userInfo[String.userInfoChildIDKey] as? String == child.id.uuidString
        else { return nil }
        let requestSeriesID = request.content.userInfo[String.userInfoSeriesIDKey] as? String
        if request.identifier == seriesID
          || request.identifier.hasPrefix("\(seriesID)#")
          || requestSeriesID == seriesID
        {
          return request.identifier
        }
        return nil
      }
      if !existingIdentifiers.isEmpty {
        center.removePendingNotificationRequests(withIdentifiers: existingIdentifiers)
      }

      let scheduleWeekdays = recurrence == .daily ? [nil] : requestedWeekdays.map(Optional.some)
      for weekday in scheduleWeekdays {
        let content = UNMutableNotificationContent()
        let title = await MainActor.run {
          String(
            localized: "reminder.notification.title \(child.name)",
            bundle: .module
          )
        }
        let body = await MainActor.run {
          String(
            localized: "reminder.notification.body \(description)",
            bundle: .module
          )
        }
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = .categoryIdentifier
        content.userInfo = [
          String.userInfoChildIDKey: child.id.uuidString,
          String.userInfoDescriptionKey: description,
          String.userInfoSeriesIDKey: seriesID,
          String.userInfoRecurrenceKey: recurrence.rawValue,
          String.userInfoWeekdaysKey: requestedWeekdays
        ]

        let trigger = UNCalendarNotificationTrigger(
          dateMatching: DateComponents(hour: hour, minute: minute, weekday: weekday),
          repeats: true
        )
        let requestIdentifier =
          if let weekday {
            "\(seriesID)#\(weekday)"
          } else {
            seriesID
          }
        let request = UNNotificationRequest(
          identifier: requestIdentifier,
          content: content,
          trigger: trigger
        )
        try await center.add(request)
      }
    }

    return ReminderClient(
      loadReminders: { childID in
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        let reminders = requests.compactMap { request in
          ScheduledReminder(request: request, childID: childID)
        }
        return ScheduledReminder.grouped(reminders)
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
        try await scheduleRecurring(
          id,
          child,
          description,
          hour,
          minute,
          .daily,
          []
        )
      },
      deleteReminders: { identifiers in
        UNUserNotificationCenter.current()
          .removePendingNotificationRequests(withIdentifiers: identifiers)
      },
      scheduleRecurringReminder: scheduleRecurring
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
