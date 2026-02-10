import CustomDump
import Dependencies
import DependenciesTestSupport
import Foundation
import Testing

@testable import AppFeature

@Suite(.serialized)
struct ReminderSheetModelTests {
  actor Recorder {
    var deletedIdentifiers: [String] = []
    var loadCount = 0

    func nextLoadCount() -> Int {
      loadCount += 1
      return loadCount
    }

    func setDeletedIdentifiers(_ identifiers: [String]) {
      deletedIdentifiers = identifiers
    }
  }

  let child = Child(id: UUID(1), name: "Mila")

  @Test
  func initialState() {
    let model = ReminderSheetModel(child: child)

    expectNoDifference(model.child.id, child.id)
    expectNoDifference(model.child.name, child.name)
    expectNoDifference(model.reminders, [ScheduledReminder]())
    expectNoDifference(model.isLoading, false)
  }

  @Test(
    .dependencies {
      $0.reminderClient = ReminderClient(
        loadReminders: { _ in
          [
            ScheduledReminder(
              id: "late",
              timeText: "9:30 PM",
              description: "Late",
              sortKey: 21 * 60 + 30,
              hour: 21,
              minute: 30
            ),
            ScheduledReminder(
              id: "early",
              timeText: "7:15 AM",
              description: "Early",
              sortKey: 7 * 60 + 15,
              hour: 7,
              minute: 15
            )
          ]
        },
        authorizationStatus: { .authorized },
        requestAuthorization: { true },
        scheduleReminder: { _, _, _, _, _ in },
        deleteReminders: { _ in }
      )
    }
  )
  func loadRemindersTaskSortsByTime() async {
    let model = ReminderSheetModel(child: child)

    await model.loadRemindersTask()

    expectNoDifference(model.reminders.map(\.id), ["early", "late"])
  }

  @Test
  func deleteRemindersDeletesSelectedOffsetsAndReloads() async {
    let recorder = Recorder()

    let model = withDependencies {
      $0.reminderClient = ReminderClient(
        loadReminders: { _ in
          if await recorder.nextLoadCount() == 1 {
            return [
              ScheduledReminder(
                id: "morning",
                timeText: "8:00 AM",
                description: "Milk",
                sortKey: 8 * 60,
                hour: 8,
                minute: 0
              ),
              ScheduledReminder(
                id: "evening",
                timeText: "6:00 PM",
                description: "Bath",
                sortKey: 18 * 60,
                hour: 18,
                minute: 0
              )
            ]
          } else {
            return [
              ScheduledReminder(
                id: "evening",
                timeText: "6:00 PM",
                description: "Bath",
                sortKey: 18 * 60,
                hour: 18,
                minute: 0
              )
            ]
          }
        },
        authorizationStatus: { .authorized },
        requestAuthorization: { true },
        scheduleReminder: { _, _, _, _, _ in },
        deleteReminders: { await recorder.setDeletedIdentifiers($0) }
      )
    } operation: {
      ReminderSheetModel(child: child)
    }

    await model.loadRemindersTask()
    await model.deleteReminders(at: IndexSet(integer: 0))

    let deletedIdentifiers = await recorder.deletedIdentifiers
    let loadCount = await recorder.loadCount

    expectNoDifference(deletedIdentifiers, ["morning"])
    expectNoDifference(loadCount, 2)
    expectNoDifference(model.reminders.map(\.id), ["evening"])
  }
}
