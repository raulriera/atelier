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
        case .weekly(let weekday, let hour, let minute):
            "\(Self.weekdayName(weekday)) at \(Self.formatTime(hour: hour, minute: minute))"
        case .monthly(let day, let hour, let minute):
            "Monthly on day \(day) at \(Self.formatTime(hour: hour, minute: minute))"
        case .cron:
            "Custom schedule"
        }
    }

    /// Converts the schedule to a launchd `StartCalendarInterval` dictionary.
    ///
    /// Returns `nil` for `.manual` since it never auto-fires.
    public var calendarIntervalDictionary: [String: Int]? {
        switch self {
        case .manual:
            nil
        case .hourly:
            ["Minute": 0]
        case .daily(let hour, let minute):
            ["Hour": hour, "Minute": minute]
        case .weekly(let weekday, let hour, let minute):
            ["Weekday": weekday, "Hour": hour, "Minute": minute]
        case .monthly(let day, let hour, let minute):
            ["Day": day, "Hour": hour, "Minute": minute]
        case .cron(let minute, let hour, let day, let month, let weekday):
            Self.buildCronDictionary(minute: minute, hour: hour, day: day, month: month, weekday: weekday)
        }
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
