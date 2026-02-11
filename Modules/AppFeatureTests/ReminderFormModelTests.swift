import CustomDump
import Dependencies
import DependenciesTestSupport
import Foundation
import Testing

@testable import AppFeature

@Suite(.serialized)
struct ReminderFormModelTests {
  actor Recorder {
    var scheduledID: String?
    var scheduledChildID: Child.ID?
    var scheduledDescription = ""
    var scheduledHour = -1
    var scheduledMinute = -1
    var scheduledRecurrence: ReminderRecurrence?
    var scheduledWeekdays: Set<Int> = []

    func setSchedule(
      id: String?,
      child: Child,
      description: String,
      hour: Int,
      minute: Int
    ) {
      scheduledID = id
      scheduledChildID = child.id
      scheduledDescription = description
      scheduledHour = hour
      scheduledMinute = minute
      scheduledRecurrence = .daily
      scheduledWeekdays = []
    }

    func setRecurringSchedule(
      id: String?,
      child: Child,
      description: String,
      hour: Int,
      minute: Int,
      recurrence: ReminderRecurrence,
      weekdays: Set<Int>
    ) {
      setSchedule(
        id: id,
        child: child,
        description: description,
        hour: hour,
        minute: minute
      )
      scheduledRecurrence = recurrence
      scheduledWeekdays = weekdays
    }
  }

  let child = Child(id: UUID(1), name: "Mila")

  @Test
  func initialStateForNewReminder() {
    let model = ReminderFormModel(child: child, reminder: nil)

    expectNoDifference(model.child.id, child.id)
    expectNoDifference(model.reminder != nil, false)
    expectNoDifference(model.description, "")
    expectNoDifference(model.recurrence, .daily)
    expectNoDifference(model.selectedWeekdays, [])
    expectNoDifference(model.isSaving, false)
    expectNoDifference(model.errorMessage != nil, false)
    expectNoDifference(model.isSaveDisabled, true)
  }

  @Test
  func initialStateForExistingReminderPrefillsValues() {
    let reminder = ScheduledReminder(
      id: "existing",
      timeText: "7:45 AM",
      description: "Bottle",
      sortKey: 7 * 60 + 45,
      hour: 7,
      minute: 45
    )
    let model = ReminderFormModel(child: child, reminder: reminder)

    expectNoDifference(model.description, "Bottle")
    expectNoDifference(model.recurrence, .daily)
    expectNoDifference(model.selectedWeekdays, [])
    let components = Calendar.current.dateComponents([.hour, .minute], from: model.time)
    expectNoDifference(components.hour, 7)
    expectNoDifference(components.minute, 45)
  }

  @Test
  func initialStateForExistingWeeklyReminderPrefillsRecurrenceAndWeekdays() {
    let reminder = ScheduledReminder(
      id: "weekly",
      timeText: "9:05 AM",
      description: "Medicine",
      sortKey: 9 * 60 + 5,
      hour: 9,
      minute: 5,
      recurrence: .weekly,
      weekdays: [1, 3]
    )
    let model = ReminderFormModel(child: child, reminder: reminder)

    expectNoDifference(model.recurrence, .weekly)
    expectNoDifference(model.selectedWeekdays, [1, 3])
    let components = Calendar.current.dateComponents([.hour, .minute], from: model.time)
    expectNoDifference(components.hour, 9)
    expectNoDifference(components.minute, 5)
  }

  @Test(
    .dependencies {
      $0.reminderClient = ReminderClient(
        loadReminders: { _ in [] },
        authorizationStatus: { .denied },
        requestAuthorization: { true },
        scheduleReminder: Self.noopScheduleReminder,
        deleteReminders: { _ in }
      )
    }
  )
  func saveButtonTappedWithDeniedAuthorizationSetsError() async {
    let model = ReminderFormModel(child: child, reminder: nil)
    model.description = "Morning milk"

    let result = await model.saveButtonTapped()

    expectNoDifference(result, false)
    expectNoDifference(model.errorMessage != nil, true)
    expectNoDifference(model.isSaving, false)
  }

  @Test
  func saveButtonTappedRequestsAuthorizationAndSchedulesReminder() async {
    let recorder = Recorder()
    let scheduleRecurring: ReminderClient.ScheduleRecurringReminder = {
      id, child, description, hour, minute, recurrence, weekdays in
      await recorder.setRecurringSchedule(
        id: id,
        child: child,
        description: description,
        hour: hour,
        minute: minute,
        recurrence: recurrence,
        weekdays: weekdays
      )
    }
    let reminder = ScheduledReminder(
      id: "existing",
      timeText: "7:45 AM",
      description: "Bottle",
      sortKey: 7 * 60 + 45,
      hour: 7,
      minute: 45
    )
    let model = withDependencies {
      $0.reminderClient = ReminderClient(
        loadReminders: { _ in [] },
        authorizationStatus: { .notDetermined },
        requestAuthorization: { true },
        scheduleReminder: Self.noopScheduleReminder,
        deleteReminders: { _ in },
        scheduleRecurringReminder: scheduleRecurring
      )
    } operation: {
      ReminderFormModel(child: child, reminder: reminder)
    }

    model.description = "Morning milk"
    model.time = Calendar.current.date(from: DateComponents(hour: 9, minute: 5)) ?? Date()

    let result = await model.saveButtonTapped()

    let scheduledID = await recorder.scheduledID
    let scheduledChildID = await recorder.scheduledChildID
    let scheduledDescription = await recorder.scheduledDescription
    let scheduledHour = await recorder.scheduledHour
    let scheduledMinute = await recorder.scheduledMinute
    let scheduledRecurrence = await recorder.scheduledRecurrence
    let scheduledWeekdays = await recorder.scheduledWeekdays

    expectNoDifference(result, true)
    expectNoDifference(scheduledID, "existing")
    expectNoDifference(scheduledChildID, child.id)
    expectNoDifference(scheduledDescription, "Morning milk")
    expectNoDifference(scheduledHour, 9)
    expectNoDifference(scheduledMinute, 5)
    expectNoDifference(scheduledRecurrence, .daily)
    expectNoDifference(scheduledWeekdays, [])
    expectNoDifference(model.errorMessage != nil, false)
    expectNoDifference(model.isSaving, false)
  }

  @Test
  func weeklyReminderRequiresSelectedWeekday() {
    let model = ReminderFormModel(child: child, reminder: nil)
    model.description = "Weekly dose"
    model.recurrence = .weekly
    model.selectedWeekdays = []

    expectNoDifference(model.isSaveDisabled, true)

    model.setWeekday(1, isSelected: true)

    expectNoDifference(model.isSaveDisabled, false)
    expectNoDifference(model.selectedWeekdays, [1])
  }

  @Test
  func saveButtonTappedForConcreteSundayTimeSchedulesSundayWeeklyReminder() async {
    let recorder = Recorder()
    let scheduleRecurring: ReminderClient.ScheduleRecurringReminder = {
      id, child, description, hour, minute, recurrence, weekdays in
      await recorder.setRecurringSchedule(
        id: id,
        child: child,
        description: description,
        hour: hour,
        minute: minute,
        recurrence: recurrence,
        weekdays: weekdays
      )
    }
    let model = withDependencies {
      $0.reminderClient = ReminderClient(
        loadReminders: { _ in [] },
        authorizationStatus: { .authorized },
        requestAuthorization: { true },
        scheduleReminder: Self.noopScheduleReminder,
        deleteReminders: { _ in },
        scheduleRecurringReminder: scheduleRecurring
      )
    } operation: {
      ReminderFormModel(child: child, reminder: nil)
    }

    let sundayAtNineOhFive = Calendar.current.date(
      from: DateComponents(
        year: 2024,
        month: 1,
        day: 7,
        hour: 9,
        minute: 5
      )
    ) ?? Date()

    model.description = "Sunday medicine"
    model.recurrence = .weekly
    model.selectedWeekdays = [1]
    model.time = sundayAtNineOhFive

    let result = await model.saveButtonTapped()

    let scheduledHour = await recorder.scheduledHour
    let scheduledMinute = await recorder.scheduledMinute
    let scheduledRecurrence = await recorder.scheduledRecurrence
    let scheduledWeekdays = await recorder.scheduledWeekdays

    expectNoDifference(result, true)
    expectNoDifference(scheduledHour, 9)
    expectNoDifference(scheduledMinute, 5)
    expectNoDifference(scheduledRecurrence, .weekly)
    expectNoDifference(scheduledWeekdays, [1])
  }

  private static func noopScheduleReminder(
    _ id: String?,
    _ child: Child,
    _ description: String,
    _ hour: Int,
    _ minute: Int
  ) async throws {}
}
