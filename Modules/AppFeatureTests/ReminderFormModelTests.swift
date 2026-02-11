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

    func setSchedule(
      id: String?,
      childID: Child.ID,
      description: String,
      hour: Int,
      minute: Int
    ) {
      scheduledID = id
      scheduledChildID = childID
      scheduledDescription = description
      scheduledHour = hour
      scheduledMinute = minute
    }
  }

  let child = Child(id: UUID(1), name: "Mila")

  @Test
  func initialStateForNewReminder() {
    let model = ReminderFormModel(child: child, reminder: nil)

    expectNoDifference(model.child.id, child.id)
    expectNoDifference(model.reminder != nil, false)
    expectNoDifference(model.description, "")
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
    let components = Calendar.current.dateComponents([.hour, .minute], from: model.time)
    expectNoDifference(components.hour, 7)
    expectNoDifference(components.minute, 45)
  }

  @Test(
    .dependencies {
      $0.reminderClient = ReminderClient(
        loadReminders: { _ in [] },
        authorizationStatus: { .denied },
        requestAuthorization: { true },
        scheduleReminder: { _, _, _, _, _ in },
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
        scheduleReminder: { id, child, description, hour, minute in
          await recorder.setSchedule(
            id: id,
            childID: child.id,
            description: description,
            hour: hour,
            minute: minute
          )
        },
        deleteReminders: { _ in }
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

    expectNoDifference(result, true)
    expectNoDifference(scheduledID, "existing")
    expectNoDifference(scheduledChildID, child.id)
    expectNoDifference(scheduledDescription, "Morning milk")
    expectNoDifference(scheduledHour, 9)
    expectNoDifference(scheduledMinute, 5)
    expectNoDifference(model.errorMessage != nil, false)
    expectNoDifference(model.isSaving, false)
  }
}
