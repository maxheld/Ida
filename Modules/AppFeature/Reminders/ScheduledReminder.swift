import UserNotifications

nonisolated struct ScheduledReminder: Identifiable, Sendable, Equatable {
  let id: String
  let timeText: String
  let description: String
  let sortKey: Int
  let hour: Int
  let minute: Int

  init(
    id: String,
    timeText: String,
    description: String,
    sortKey: Int,
    hour: Int,
    minute: Int
  ) {
    self.id = id
    self.timeText = timeText
    self.description = description
    self.sortKey = sortKey
    self.hour = hour
    self.minute = minute
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
    let displayDate = Calendar.current.date(from: .init(hour: hour, minute: minute)) ?? Date()
    self.id = request.identifier
    self.timeText = displayDate.formatted(date: .omitted, time: .shortened)
    self.description = request.content.userInfo[String.userInfoDescriptionKey] as? String ?? ""
    self.sortKey = (hour * 60) + minute
    self.hour = hour
    self.minute = minute
  }
}
