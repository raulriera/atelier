import Foundation
import Testing
@testable import AtelierKit

@Suite("ScheduledTask")
struct ScheduledTaskTests {

    // MARK: - TaskSchedule.displayName

    @Test func manualDisplayName() {
        #expect(TaskSchedule.manual.displayName == "Manual")
    }

    @Test func hourlyDisplayName() {
        #expect(TaskSchedule.hourly.displayName == "Every hour")
    }

    @Test func dailyDisplayName() {
        let schedule = TaskSchedule.daily(hour: 8, minute: 0)
        #expect(schedule.displayName == "Daily at 8:00 AM")
    }

    @Test func dailyPMDisplayName() {
        let schedule = TaskSchedule.daily(hour: 15, minute: 30)
        #expect(schedule.displayName == "Daily at 3:30 PM")
    }

    @Test func dailyNoonDisplayName() {
        let schedule = TaskSchedule.daily(hour: 12, minute: 0)
        #expect(schedule.displayName == "Daily at 12:00 PM")
    }

    @Test func dailyMidnightDisplayName() {
        let schedule = TaskSchedule.daily(hour: 0, minute: 0)
        #expect(schedule.displayName == "Daily at 12:00 AM")
    }

    @Test func weeklyDisplayName() {
        let schedule = TaskSchedule.weekly(weekday: 1, hour: 15, minute: 0)
        #expect(schedule.displayName == "Monday at 3:00 PM")
    }

    @Test func weeklySundayDisplayName() {
        let schedule = TaskSchedule.weekly(weekday: 0, hour: 9, minute: 30)
        #expect(schedule.displayName == "Sunday at 9:30 AM")
    }

    @Test func monthlyDisplayName() {
        let schedule = TaskSchedule.monthly(day: 1, hour: 9, minute: 0)
        #expect(schedule.displayName == "Monthly on day 1 at 9:00 AM")
    }

    @Test func cronDisplayName() {
        let schedule = TaskSchedule.cron(minute: 0, hour: 8, day: nil, month: nil, weekday: nil)
        #expect(schedule.displayName == "Custom schedule")
    }

    // MARK: - TaskSchedule.calendarIntervalDictionary

    @Test func manualCalendarIntervalIsNil() {
        #expect(TaskSchedule.manual.calendarIntervalDictionary == nil)
    }

    @Test func hourlyCalendarInterval() {
        let dict = TaskSchedule.hourly.calendarIntervalDictionary
        #expect(dict == ["Minute": 0])
    }

    @Test func dailyCalendarInterval() {
        let dict = TaskSchedule.daily(hour: 8, minute: 0).calendarIntervalDictionary
        #expect(dict == ["Hour": 8, "Minute": 0])
    }

    @Test func weeklyCalendarInterval() {
        let dict = TaskSchedule.weekly(weekday: 1, hour: 15, minute: 0).calendarIntervalDictionary
        #expect(dict == ["Weekday": 1, "Hour": 15, "Minute": 0])
    }

    @Test func monthlyCalendarInterval() {
        let dict = TaskSchedule.monthly(day: 15, hour: 9, minute: 30).calendarIntervalDictionary
        #expect(dict == ["Day": 15, "Hour": 9, "Minute": 30])
    }

    @Test func cronCalendarIntervalWithAllFields() {
        let dict = TaskSchedule.cron(minute: 30, hour: 14, day: 1, month: 6, weekday: 3)
            .calendarIntervalDictionary
        #expect(dict == ["Minute": 30, "Hour": 14, "Day": 1, "Month": 6, "Weekday": 3])
    }

    @Test func cronCalendarIntervalWithPartialFields() {
        let dict = TaskSchedule.cron(minute: 0, hour: nil, day: nil, month: nil, weekday: nil)
            .calendarIntervalDictionary
        #expect(dict == ["Minute": 0])
    }

    @Test func cronCalendarIntervalAllNilReturnsNil() {
        let dict = TaskSchedule.cron(minute: nil, hour: nil, day: nil, month: nil, weekday: nil)
            .calendarIntervalDictionary
        #expect(dict == nil)
    }

    // MARK: - logURL

    @Test func logURLPointsToTasksDirectory() {
        let task = ScheduledTask(
            name: "Test",
            prompt: "Do something",
            schedule: .hourly,
            projectPath: "/tmp"
        )

        let expected = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/Atelier/tasks/\(task.id.uuidString).log")

        #expect(task.logURL == expected)
    }

    @Test func logURLIsUniquePerTask() {
        let task1 = ScheduledTask(name: "A", prompt: "a", schedule: .hourly, projectPath: "/tmp")
        let task2 = ScheduledTask(name: "B", prompt: "b", schedule: .hourly, projectPath: "/tmp")

        #expect(task1.logURL != task2.logURL)
    }

    // MARK: - ScheduledTask Codable round-trip

    @Test func scheduledTaskCodableRoundTrip() throws {
        let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
        let task = ScheduledTask(
            name: "Test task",
            description: "A test",
            prompt: "Do something",
            schedule: .daily(hour: 9, minute: 0),
            model: "sonnet",
            projectPath: "/tmp/project",
            lastRunDate: fixedDate,
            lastRunSucceeded: true,
            createdAt: fixedDate
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(task)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ScheduledTask.self, from: data)

        #expect(decoded.id == task.id)
        #expect(decoded.name == task.name)
        #expect(decoded.description == task.description)
        #expect(decoded.prompt == task.prompt)
        #expect(decoded.schedule == task.schedule)
        #expect(decoded.model == task.model)
        #expect(decoded.projectPath == task.projectPath)
        #expect(decoded.isPaused == task.isPaused)
        #expect(decoded.lastRunDate == task.lastRunDate)
        #expect(decoded.lastRunSucceeded == task.lastRunSucceeded)
        #expect(decoded.createdAt == task.createdAt)
    }

    @Test func scheduledTaskWithManualScheduleRoundTrips() throws {
        let task = ScheduledTask(
            name: "Manual task",
            prompt: "Run manually",
            schedule: .manual,
            projectPath: "/tmp"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(task)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ScheduledTask.self, from: data)

        #expect(decoded.schedule == .manual)
        #expect(decoded.model == nil)
        #expect(decoded.lastRunDate == nil)
        #expect(decoded.lastRunSucceeded == nil)
    }

    @Test func scheduledTaskWithCronScheduleRoundTrips() throws {
        let task = ScheduledTask(
            name: "Cron task",
            prompt: "Custom schedule",
            schedule: .cron(minute: 30, hour: nil, day: 1, month: nil, weekday: nil),
            projectPath: "/tmp"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(task)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ScheduledTask.self, from: data)

        #expect(decoded.schedule == .cron(minute: 30, hour: nil, day: 1, month: nil, weekday: nil))
    }
}
