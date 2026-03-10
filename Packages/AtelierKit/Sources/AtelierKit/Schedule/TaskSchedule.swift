import Foundation

/// When a scheduled task should fire.
///
/// Each case maps to a launchd `StartCalendarInterval` dictionary.
/// The `.manual` case never auto-fires and is intended for run-now-only tasks.
public enum TaskSchedule: Sendable, Codable, Hashable {
    /// Never auto-fires; the user triggers it manually.
    case manual
    /// Fires at the top of every hour.
    case hourly
    /// Fires once per day at the given hour and minute.
    case daily(hour: Int, minute: Int)
    /// Fires Monday through Friday at the given time.
    case weekdays(hour: Int, minute: Int)
    /// Fires Saturday and Sunday at the given time.
    case weekends(hour: Int, minute: Int)
    /// Fires once per week on the given weekday (0 = Sunday) at the given time.
    case weekly(weekday: Int, hour: Int, minute: Int)
    /// Fires once per month on the given day at the given time.
    case monthly(day: Int, hour: Int, minute: Int)
    /// A custom schedule expressed as individual calendar interval fields.
    ///
    /// Any `nil` field acts as a wildcard (matches every value).
    case cron(minute: Int?, hour: Int?, day: Int?, month: Int?, weekday: Int?)

    /// A human-readable description of the schedule.
    public var displayName: String {
        switch self {
        case .manual:
            "Manual"
        case .hourly:
            "Every hour"
        case .daily(let hour, let minute):
            "Daily at \(Self.formatTime(hour: hour, minute: minute))"
        case .weekdays(let hour, let minute):
            "Weekdays at \(Self.formatTime(hour: hour, minute: minute))"
        case .weekends(let hour, let minute):
            "Weekends at \(Self.formatTime(hour: hour, minute: minute))"
        case .weekly(let weekday, let hour, let minute):
            "\(Self.weekdayName(weekday)) at \(Self.formatTime(hour: hour, minute: minute))"
        case .monthly(let day, let hour, let minute):
            "Monthly on day \(day) at \(Self.formatTime(hour: hour, minute: minute))"
        case .cron:
            "Custom schedule"
        }
    }

    /// Converts the schedule to launchd `StartCalendarInterval` dictionaries.
    ///
    /// Returns `nil` for `.manual` since it never auto-fires.
    /// Weekdays and weekends expand into multiple intervals (one per day).
    public var calendarIntervals: [[String: Int]]? {
        switch self {
        case .manual:
            nil
        case .hourly:
            [["Minute": 0]]
        case .daily(let hour, let minute):
            [["Hour": hour, "Minute": minute]]
        case .weekdays(let hour, let minute):
            (1...5).map { ["Weekday": $0, "Hour": hour, "Minute": minute] }
        case .weekends(let hour, let minute):
            [0, 6].map { ["Weekday": $0, "Hour": hour, "Minute": minute] }
        case .weekly(let weekday, let hour, let minute):
            [["Weekday": weekday, "Hour": hour, "Minute": minute]]
        case .monthly(let day, let hour, let minute):
            [["Day": day, "Hour": hour, "Minute": minute]]
        case .cron(let minute, let hour, let day, let month, let weekday):
            if let dict = Self.buildCronDictionary(minute: minute, hour: hour, day: day, month: month, weekday: weekday) {
                [dict]
            } else {
                nil
            }
        }
    }

    /// Whether this schedule is due at the given date.
    ///
    /// Matches current calendar components against `calendarIntervals`
    /// using the same algorithm launchd uses for `StartCalendarInterval`:
    /// each key must match the corresponding component; absent keys are wildcards.
    /// Allows +/- 1 minute tolerance for sleep/wake edge cases.
    public func isDue(at date: Date) -> Bool {
        guard let intervals = calendarIntervals else { return false }

        let calendar = Calendar.current
        let components = calendar.dateComponents([.minute, .hour, .weekday, .day, .month], from: date)
        let currentMinute = components.minute!
        let currentHour = components.hour!
        // launchd uses 0=Sunday; Calendar uses 1=Sunday — adjust
        let currentWeekday = components.weekday! - 1
        let currentDay = components.day!
        let currentMonth = components.month!

        for interval in intervals {
            var matches = true

            if let minute = interval["Minute"] {
                let diff = abs(currentMinute - minute)
                if diff > 1 && diff < 59 { matches = false }
            }
            if let hour = interval["Hour"], hour != currentHour { matches = false }
            if let weekday = interval["Weekday"], weekday != currentWeekday { matches = false }
            if let day = interval["Day"], day != currentDay { matches = false }
            if let month = interval["Month"], month != currentMonth { matches = false }

            if matches { return true }
        }

        return false
    }

    // MARK: - Private Helpers

    private static func formatTime(hour: Int, minute: Int) -> String {
        let period = hour >= 12 ? "PM" : "AM"
        let displayHour = hour % 12 == 0 ? 12 : hour % 12
        return String(format: "%d:%02d %@", displayHour, minute, period)
    }

    private static func weekdayName(_ weekday: Int) -> String {
        switch weekday {
        case 0: "Sunday"
        case 1: "Monday"
        case 2: "Tuesday"
        case 3: "Wednesday"
        case 4: "Thursday"
        case 5: "Friday"
        case 6: "Saturday"
        default: "Day \(weekday)"
        }
    }

    private static func buildCronDictionary(
        minute: Int?, hour: Int?, day: Int?, month: Int?, weekday: Int?
    ) -> [String: Int]? {
        var dict: [String: Int] = [:]
        if let minute { dict["Minute"] = minute }
        if let hour { dict["Hour"] = hour }
        if let day { dict["Day"] = day }
        if let month { dict["Month"] = month }
        if let weekday { dict["Weekday"] = weekday }
        return dict.isEmpty ? nil : dict
    }
}
