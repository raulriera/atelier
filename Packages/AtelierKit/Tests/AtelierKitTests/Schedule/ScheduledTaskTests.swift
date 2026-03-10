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

    @Test func weekdaysDisplayName() {
        let schedule = TaskSchedule.weekdays(hour: 9, minute: 0)
        #expect(schedule.displayName == "Weekdays at 9:00 AM")
    }

    @Test func weekendsDisplayName() {
        let schedule = TaskSchedule.weekends(hour: 10, minute: 30)
        #expect(schedule.displayName == "Weekends at 10:30 AM")
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

    // MARK: - TaskSchedule.calendarIntervals

    @Test func manualCalendarIntervalsIsNil() {
        #expect(TaskSchedule.manual.calendarIntervals == nil)
    }

    @Test func hourlyCalendarIntervals() {
        let intervals = TaskSchedule.hourly.calendarIntervals
        #expect(intervals == [["Minute": 0]])
    }

    @Test func dailyCalendarIntervals() {
        let intervals = TaskSchedule.daily(hour: 8, minute: 0).calendarIntervals
        #expect(intervals == [["Hour": 8, "Minute": 0]])
    }

    @Test func weekdaysCalendarIntervals() {
        let intervals = TaskSchedule.weekdays(hour: 9, minute: 0).calendarIntervals
        #expect(intervals?.count == 5)
        #expect(intervals?[0] == ["Weekday": 1, "Hour": 9, "Minute": 0])
        #expect(intervals?[4] == ["Weekday": 5, "Hour": 9, "Minute": 0])
    }

    @Test func weekendsCalendarIntervals() {
        let intervals = TaskSchedule.weekends(hour: 10, minute: 30).calendarIntervals
        #expect(intervals?.count == 2)
        #expect(intervals?[0] == ["Weekday": 0, "Hour": 10, "Minute": 30])
        #expect(intervals?[1] == ["Weekday": 6, "Hour": 10, "Minute": 30])
    }

    @Test func weeklyCalendarIntervals() {
        let intervals = TaskSchedule.weekly(weekday: 1, hour: 15, minute: 0).calendarIntervals
        #expect(intervals == [["Weekday": 1, "Hour": 15, "Minute": 0]])
    }

    @Test func monthlyCalendarIntervals() {
        let intervals = TaskSchedule.monthly(day: 15, hour: 9, minute: 30).calendarIntervals
        #expect(intervals == [["Day": 15, "Hour": 9, "Minute": 30]])
    }

    @Test func cronCalendarIntervalsWithAllFields() {
        let intervals = TaskSchedule.cron(minute: 30, hour: 14, day: 1, month: 6, weekday: 3)
            .calendarIntervals
        #expect(intervals == [["Minute": 30, "Hour": 14, "Day": 1, "Month": 6, "Weekday": 3]])
    }

    @Test func cronCalendarIntervalsWithPartialFields() {
        let intervals = TaskSchedule.cron(minute: 0, hour: nil, day: nil, month: nil, weekday: nil)
            .calendarIntervals
        #expect(intervals == [["Minute": 0]])
    }

    @Test func cronCalendarIntervalsAllNilReturnsNil() {
        let intervals = TaskSchedule.cron(minute: nil, hour: nil, day: nil, month: nil, weekday: nil)
            .calendarIntervals
        #expect(intervals == nil)
    }

    // MARK: - TaskSchedule.isDue

    /// Helper: creates a Date for a specific calendar moment.
    private func makeDate(
        year: Int = 2026, month: Int = 3, day: Int = 10,
        hour: Int = 9, minute: Int = 0
    ) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components)!
    }

    @Test func manualIsNeverDue() {
        #expect(!TaskSchedule.manual.isDue(at: makeDate()))
    }

    @Test func hourlyIsDueAtTopOfHour() {
        #expect(TaskSchedule.hourly.isDue(at: makeDate(minute: 0)))
    }

    @Test func hourlyIsNotDueAtMinute30() {
        #expect(!TaskSchedule.hourly.isDue(at: makeDate(minute: 30)))
    }

    @Test func hourlyToleratesOneMinuteLate() {
        #expect(TaskSchedule.hourly.isDue(at: makeDate(minute: 1)))
    }

    @Test func dailyIsDueAtExactTime() {
        let schedule = TaskSchedule.daily(hour: 9, minute: 0)
        #expect(schedule.isDue(at: makeDate(hour: 9, minute: 0)))
    }

    @Test func dailyIsNotDueAtWrongHour() {
        let schedule = TaskSchedule.daily(hour: 9, minute: 0)
        #expect(!schedule.isDue(at: makeDate(hour: 10, minute: 0)))
    }

    @Test func weekdaysIsDueOnTuesday() {
        // 2026-03-10 is a Tuesday (weekday index 2 in 0=Sunday system)
        let schedule = TaskSchedule.weekdays(hour: 9, minute: 0)
        #expect(schedule.isDue(at: makeDate(year: 2026, month: 3, day: 10, hour: 9, minute: 0)))
    }

    @Test func weekdaysIsNotDueOnSunday() {
        // 2026-03-08 is a Sunday
        let schedule = TaskSchedule.weekdays(hour: 9, minute: 0)
        #expect(!schedule.isDue(at: makeDate(year: 2026, month: 3, day: 8, hour: 9, minute: 0)))
    }

    @Test func weekendsIsDueOnSunday() {
        // 2026-03-08 is a Sunday
        let schedule = TaskSchedule.weekends(hour: 10, minute: 0)
        #expect(schedule.isDue(at: makeDate(year: 2026, month: 3, day: 8, hour: 10, minute: 0)))
    }

    @Test func weekendsIsNotDueOnMonday() {
        // 2026-03-09 is a Monday
        let schedule = TaskSchedule.weekends(hour: 10, minute: 0)
        #expect(!schedule.isDue(at: makeDate(year: 2026, month: 3, day: 9, hour: 10, minute: 0)))
    }

    @Test func weeklyIsDueOnCorrectDay() {
        // 2026-03-10 is Tuesday = weekday 2 (0=Sun)
        let schedule = TaskSchedule.weekly(weekday: 2, hour: 15, minute: 0)
        #expect(schedule.isDue(at: makeDate(year: 2026, month: 3, day: 10, hour: 15, minute: 0)))
    }

    @Test func weeklyIsNotDueOnWrongDay() {
        // 2026-03-10 is Tuesday = weekday 2
        let schedule = TaskSchedule.weekly(weekday: 5, hour: 15, minute: 0)
        #expect(!schedule.isDue(at: makeDate(year: 2026, month: 3, day: 10, hour: 15, minute: 0)))
    }

    @Test func monthlyIsDueOnCorrectDay() {
        let schedule = TaskSchedule.monthly(day: 10, hour: 9, minute: 0)
        #expect(schedule.isDue(at: makeDate(day: 10, hour: 9, minute: 0)))
    }

    @Test func monthlyIsNotDueOnWrongDay() {
        let schedule = TaskSchedule.monthly(day: 15, hour: 9, minute: 0)
        #expect(!schedule.isDue(at: makeDate(day: 10, hour: 9, minute: 0)))
    }

    @Test func minuteToleranceWrapsAroundHour() {
        // Minute 59, schedule says Minute 0 — diff is 59, should match (wrap tolerance)
        let schedule = TaskSchedule.hourly
        #expect(schedule.isDue(at: makeDate(minute: 59)))
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
