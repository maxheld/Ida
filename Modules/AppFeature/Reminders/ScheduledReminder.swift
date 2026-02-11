import UserNotifications

nonisolated enum ReminderRecurrence: String, CaseIterable, Sendable, Equatable {
  case daily
  case weekly

  @MainActor
  var title: String {
    switch self {
    case .daily:
      return String(localized: "reminder.recurrence.daily", bundle: .module)
    case .weekly:
      return String(localized: "reminder.recurrence.weekly", bundle: .module)
    }
  }
}

nonisolated struct ReminderWeekday: Identifiable, Hashable, Sendable {
  let rawValue: Int

  var id: Int { rawValue }

  init?(_ rawValue: Int) {
    guard (1...7).contains(rawValue) else { return nil }
    self.rawValue = rawValue
  }

  var title: String {
    let symbols = Calendar.current.weekdaySymbols
    let index = rawValue - 1
    guard symbols.indices.contains(index) else { return "" }
    return symbols[index]
  }

  static func orderedWeekdays(
    calendar: Calendar = .current
  ) -> [ReminderWeekday] {
    let firstWeekdayIndex = max(min(calendar.firstWeekday, 7), 1) - 1
    let all = (1...7).compactMap(Self.init)
    let head = all[firstWeekdayIndex...]
    let tail = all[..<firstWeekdayIndex]
    return Array(head + tail)
  }
}

nonisolated struct ScheduledReminder: Identifiable, Sendable, Equatable {
  let id: String
  let requestIDs: [String]
  let timeText: String
  let description: String
  let sortKey: Int
  let hour: Int
  let minute: Int
  let recurrence: ReminderRecurrence
  let weekdays: Set<Int>

  @MainActor
  var recurrenceText: String {
    switch recurrence {
    case .daily:
      return ReminderRecurrence.daily.title
    case .weekly:
      let selectedDays = ReminderWeekday
        .orderedWeekdays()
        .filter { weekdays.contains($0.rawValue) }
        .map(\.title)
      if selectedDays.isEmpty {
        return ReminderRecurrence.weekly.title
      }
      return selectedDays.joined(separator: ", ")
    }
  }

  @MainActor
  var listSubtitle: String {
    guard recurrence == .weekly else { return description }
    if description.isEmpty { return recurrenceText }
    return "\(recurrenceText) • \(description)"
  }

  init(
    id: String,
    requestIDs: [String]? = nil,
    timeText: String,
    description: String,
    sortKey: Int,
    hour: Int,
    minute: Int,
    recurrence: ReminderRecurrence = .daily,
    weekdays: Set<Int> = []
  ) {
    self.id = id
    self.requestIDs = (requestIDs ?? [id]).sorted()
    self.timeText = timeText
    self.description = description
    self.sortKey = sortKey
    self.hour = hour
    self.minute = minute
    self.recurrence = recurrence
    self.weekdays = weekdays.filter { (1...7).contains($0) }
  }

  init?(request: UNNotificationRequest, childID: Child.ID) {
    guard
      request.content.categoryIdentifier == .categoryIdentifier,
      let childIDString = request.content.userInfo[String.userInfoChildIDKey] as? String,
      childIDString == childID.uuidString,
      let trigger = request.trigger as? UNCalendarNotificationTrigger
    else { return nil }

    let hour = trigger.dateComponents.hour ?? 0
    let minute = trigger.dateComponents.minute ?? 0
    let triggerWeekday = trigger.dateComponents.weekday
    let rawRecurrence = request.content.userInfo[String.userInfoRecurrenceKey] as? String
    let storedWeekdays = (
      request.content.userInfo[String.userInfoWeekdaysKey] as? [Int]
    ) ?? (
      request.content.userInfo[String.userInfoWeekdaysKey] as? [NSNumber]
    )?.map(\.intValue) ?? []
    let reminderRecurrence = ReminderRecurrence(rawValue: rawRecurrence ?? "")
      ?? (triggerWeekday == nil ? .daily : .weekly)
    let selectedWeekdays = Set(storedWeekdays.filter { (1...7).contains($0) })
    let weekdaySet =
      reminderRecurrence == .weekly
      ? (selectedWeekdays.isEmpty ? Set([triggerWeekday].compactMap { $0 }) : selectedWeekdays)
      : []
    let baseID = (
      request.content.userInfo[String.userInfoSeriesIDKey] as? String
    ) ?? Self.baseIdentifier(for: request.identifier)
    let displayDate = Calendar.current.date(from: .init(hour: hour, minute: minute)) ?? Date()
    self.id = baseID
    self.requestIDs = [request.identifier]
    self.timeText = displayDate.formatted(date: .omitted, time: .shortened)
    self.description = request.content.userInfo[String.userInfoDescriptionKey] as? String ?? ""
    self.sortKey = (hour * 60) + minute
    self.hour = hour
    self.minute = minute
    self.recurrence = reminderRecurrence
    self.weekdays = weekdaySet
  }

  static func grouped(_ reminders: [ScheduledReminder]) -> [ScheduledReminder] {
    var grouped: [String: (base: ScheduledReminder, requestIDs: Set<String>, weekdays: Set<Int>, hasWeeklyRecurrence: Bool)] = [:]

    for reminder in reminders {
      if var entry = grouped[reminder.id] {
        entry.requestIDs.formUnion(reminder.requestIDs)
        entry.weekdays.formUnion(reminder.weekdays)
        if reminder.recurrence == .weekly {
          entry.hasWeeklyRecurrence = true
        }
        grouped[reminder.id] = entry
      } else {
        grouped[reminder.id] = (
          base: reminder,
          requestIDs: Set(reminder.requestIDs),
          weekdays: reminder.weekdays,
          hasWeeklyRecurrence: reminder.recurrence == .weekly
        )
      }
    }

    return grouped.values.map { entry in
      let recurrence: ReminderRecurrence =
        entry.hasWeeklyRecurrence || !entry.weekdays.isEmpty
        ? .weekly
        : .daily
      return ScheduledReminder(
        id: entry.base.id,
        requestIDs: entry.requestIDs.sorted(),
        timeText: entry.base.timeText,
        description: entry.base.description,
        sortKey: entry.base.sortKey,
        hour: entry.base.hour,
        minute: entry.base.minute,
        recurrence: recurrence,
        weekdays: recurrence == .weekly ? entry.weekdays : []
      )
    }
  }

  static func baseIdentifier(for identifier: String) -> String {
    guard let separator = identifier.lastIndex(of: "#") else { return identifier }
    return String(identifier[..<separator])
  }
}
