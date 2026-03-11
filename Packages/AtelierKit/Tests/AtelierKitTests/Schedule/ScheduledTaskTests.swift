import Foundation
import Testing
@testable import AtelierKit

@Suite("ScheduledTask")
struct ScheduledTaskTests {

    // MARK: - TaskSchedule.displayName

    @Test("displayName returns expected string", arguments: [
        (TaskSchedule.manual, "Manual"),
        (.hourly, "Every hour"),
        (.daily(hour: 8, minute: 0), "Daily at 8:00 AM"),
        (.daily(hour: 15, minute: 30), "Daily at 3:30 PM"),
        (.daily(hour: 12, minute: 0), "Daily at 12:00 PM"),
        (.daily(hour: 0, minute: 0), "Daily at 12:00 AM"),
        (.weekdays(hour: 9, minute: 0), "Weekdays at 9:00 AM"),
        (.weekends(hour: 10, minute: 30), "Weekends at 10:30 AM"),
        (.weekly(weekday: 1, hour: 15, minute: 0), "Monday at 3:00 PM"),
        (.weekly(weekday: 0, hour: 9, minute: 30), "Sunday at 9:30 AM"),
        (.monthly(day: 1, hour: 9, minute: 0), "Monthly on day 1 at 9:00 AM"),
        (.cron(minute: 0, hour: 8, day: nil, month: nil, weekday: nil), "Custom schedule"),
    ])
    func displayName(schedule: TaskSchedule, expected: String) {
        #expect(schedule.displayName == expected)
    }

    // MARK: - TaskSchedule.calendarIntervals

    @Test("calendarIntervals returns expected value", arguments: [
        (TaskSchedule.manual, nil as [[String: Int]]?),
        (.hourly, [["Minute": 0]]),
        (.daily(hour: 8, minute: 0), [["Hour": 8, "Minute": 0]]),
        (.weekly(weekday: 1, hour: 15, minute: 0), [["Weekday": 1, "Hour": 15, "Minute": 0]]),
        (.monthly(day: 15, hour: 9, minute: 30), [["Day": 15, "Hour": 9, "Minute": 30]]),
        (.cron(minute: 30, hour: 14, day: 1, month: 6, weekday: 3), [["Minute": 30, "Hour": 14, "Day": 1, "Month": 6, "Weekday": 3]]),
        (.cron(minute: 0, hour: nil, day: nil, month: nil, weekday: nil), [["Minute": 0]]),
        (.cron(minute: nil, hour: nil, day: nil, month: nil, weekday: nil), nil),
    ])
    func calendarIntervals(schedule: TaskSchedule, expected: [[String: Int]]?) {
        #expect(schedule.calendarIntervals == expected)
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

    // MARK: - TaskSchedule.isDue

    /// Helper: creates a Date for a specific calendar moment.
    private static func makeDate(
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

    @Test("isDue returns true when schedule matches", arguments: [
        // hourly at top of hour
        (TaskSchedule.hourly, makeDate(minute: 0)),
        // hourly tolerates one minute late
        (.hourly, makeDate(minute: 1)),
        // hourly tolerance wraps around hour (minute 59)
        (.hourly, makeDate(minute: 59)),
        // daily at exact time
        (.daily(hour: 9, minute: 0), makeDate(hour: 9, minute: 0)),
        // weekdays on Tuesday (2026-03-10)
        (.weekdays(hour: 9, minute: 0), makeDate(year: 2026, month: 3, day: 10, hour: 9, minute: 0)),
        // weekends on Sunday (2026-03-08)
        (.weekends(hour: 10, minute: 0), makeDate(year: 2026, month: 3, day: 8, hour: 10, minute: 0)),
        // weekly on correct day (Tuesday = weekday 2)
        (.weekly(weekday: 2, hour: 15, minute: 0), makeDate(year: 2026, month: 3, day: 10, hour: 15, minute: 0)),
        // monthly on correct day
        (.monthly(day: 10, hour: 9, minute: 0), makeDate(day: 10, hour: 9, minute: 0)),
    ])
    func isDue(schedule: TaskSchedule, date: Date) {
        #expect(schedule.isDue(at: date))
    }

    @Test("isDue returns false when schedule does not match", arguments: [
        // manual is never due
        (TaskSchedule.manual, makeDate()),
        // hourly not due at minute 30
        (.hourly, makeDate(minute: 30)),
        // daily at wrong hour
        (.daily(hour: 9, minute: 0), makeDate(hour: 10, minute: 0)),
        // weekdays not due on Sunday (2026-03-08)
        (.weekdays(hour: 9, minute: 0), makeDate(year: 2026, month: 3, day: 8, hour: 9, minute: 0)),
        // weekends not due on Monday (2026-03-09)
        (.weekends(hour: 10, minute: 0), makeDate(year: 2026, month: 3, day: 9, hour: 10, minute: 0)),
        // weekly on wrong day (Friday = weekday 5, but date is Tuesday)
        (.weekly(weekday: 5, hour: 15, minute: 0), makeDate(year: 2026, month: 3, day: 10, hour: 15, minute: 0)),
        // monthly on wrong day
        (.monthly(day: 15, hour: 9, minute: 0), makeDate(day: 10, hour: 9, minute: 0)),
    ])
    func isNotDue(schedule: TaskSchedule, date: Date) {
        #expect(!schedule.isDue(at: date))
    }

    // MARK: - logURL

    @Test func logURLPointsToTasksDirectory() {
        let task = ScheduledTask(
            name: "Test",
            prompt: "Do something",
            schedule: .hourly,
            projectPath: "/tmp",
            projectId: UUID()
        )

        let expected = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/Atelier/tasks/\(task.id.uuidString).log")

        #expect(task.logURL == expected)
    }

    @Test func logURLIsUniquePerTask() {
        let task1 = ScheduledTask(name: "A", prompt: "a", schedule: .hourly, projectPath: "/tmp", projectId: UUID())
        let task2 = ScheduledTask(name: "B", prompt: "b", schedule: .hourly, projectPath: "/tmp", projectId: UUID())

        #expect(task1.logURL != task2.logURL)
    }

    // MARK: - ScheduledTask Codable round-trip

    @Test func scheduledTaskCodableRoundTrip() throws {
        let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
        let fixedProjectId = UUID()
        let task = ScheduledTask(
            name: "Test task",
            description: "A test",
            prompt: "Do something",
            schedule: .daily(hour: 9, minute: 0),
            model: "sonnet",
            projectPath: "/tmp/project",
            projectId: fixedProjectId,
            lastRunResult: TaskRunResult(
                date: fixedDate,
                succeeded: true,
                numTurns: 3,
                resultText: "Done",
                permissionDenials: [],
                durationMs: 5000,
                health: .healthy,
                userSummary: "completed successfully"
            ),
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
        #expect(decoded.projectId == fixedProjectId)
        #expect(decoded.isPaused == task.isPaused)
        #expect(decoded.lastRunResult?.succeeded == task.lastRunResult?.succeeded)
        #expect(decoded.lastRunResult?.health == task.lastRunResult?.health)
        #expect(decoded.createdAt == task.createdAt)
    }

    @Test func scheduledTaskWithManualScheduleRoundTrips() throws {
        let pid = UUID()
        let task = ScheduledTask(
            name: "Manual task",
            prompt: "Run manually",
            schedule: .manual,
            projectPath: "/tmp",
            projectId: pid
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(task)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ScheduledTask.self, from: data)

        #expect(decoded.schedule == .manual)
        #expect(decoded.projectId == pid)
        #expect(decoded.model == nil)
        #expect(decoded.lastRunResult == nil)
    }

    @Test func scheduledTaskWithCronScheduleRoundTrips() throws {
        let task = ScheduledTask(
            name: "Cron task",
            prompt: "Custom schedule",
            schedule: .cron(minute: 30, hour: nil, day: 1, month: nil, weekday: nil),
            projectPath: "/tmp",
            projectId: UUID()
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
