import Testing

/// Tests for the date-parsing logic used in the Calendar MCP helper.
///
/// The helper converts ISO date strings to JXA `new Date(...)` expressions.
/// JavaScript treats `new Date("2026-03-09")` as UTC midnight, but
/// `new Date("2026-03-09T00:00:00")` as **local** midnight. The helper's
/// `jxaLocalDateExpr` function appends `T00:00:00` to date-only strings
/// so Calendar queries always use the user's local timezone.
struct CalendarDateParsingTests {

    // MARK: - jxaLocalDateExpr logic (mirrors Helpers/atelier-calendar-mcp.swift)

    /// Mirrors the helper's `jxaLocalDateExpr` — must stay in sync.
    private func jxaLocalDateExpr(_ iso: String) -> String {
        func jxaEscape(_ s: String) -> String {
            s.replacingOccurrences(of: "\\", with: "\\\\")
             .replacingOccurrences(of: "\"", with: "\\\"")
             .replacingOccurrences(of: "\n", with: "\\n")
             .replacingOccurrences(of: "\r", with: "\\r")
             .replacingOccurrences(of: "\t", with: "\\t")
        }
        let safe = jxaEscape(iso)
        if safe.contains("T") {
            return "new Date(\"\(safe)\")"
        }
        return "new Date(\"\(safe)T00:00:00\")"
    }

    // MARK: - Date-only inputs

    @Test("Date-only string gets T00:00:00 appended for local time")
    func dateOnlyAppendsLocalMidnight() {
        let result = jxaLocalDateExpr("2026-03-09")
        #expect(result == "new Date(\"2026-03-09T00:00:00\")")
    }

    @Test("Another date-only string")
    func dateOnlyDecember() {
        let result = jxaLocalDateExpr("2026-12-25")
        #expect(result == "new Date(\"2026-12-25T00:00:00\")")
    }

    // MARK: - DateTime inputs (already have T)

    @Test("DateTime string is passed through unchanged")
    func dateTimePassedThrough() {
        let result = jxaLocalDateExpr("2026-03-09T14:30:00")
        #expect(result == "new Date(\"2026-03-09T14:30:00\")")
    }

    @Test("DateTime with timezone offset is passed through")
    func dateTimeWithOffset() {
        let result = jxaLocalDateExpr("2026-03-09T14:30:00-04:00")
        #expect(result == "new Date(\"2026-03-09T14:30:00-04:00\")")
    }

    @Test("DateTime with Z suffix is passed through")
    func dateTimeWithZulu() {
        let result = jxaLocalDateExpr("2026-03-09T00:00:00Z")
        #expect(result == "new Date(\"2026-03-09T00:00:00Z\")")
    }

    // MARK: - Edge cases

    @Test("Empty string gets T00:00:00 appended")
    func emptyString() {
        let result = jxaLocalDateExpr("")
        #expect(result == "new Date(\"T00:00:00\")")
    }

    @Test("String with special characters is escaped")
    func specialCharactersEscaped() {
        let result = jxaLocalDateExpr("2026-03-09\nmalicious")
        // Contains \n so no T, but the newline is escaped
        #expect(result == "new Date(\"2026-03-09\\nmaliciousT00:00:00\")")
    }

    // MARK: - DST boundary dates

    @Test("DST spring-forward date gets local midnight")
    func dstSpringForward() {
        // March 8, 2026 is when DST starts in North America
        let result = jxaLocalDateExpr("2026-03-08")
        #expect(result == "new Date(\"2026-03-08T00:00:00\")")
    }

    @Test("DST fall-back date gets local midnight")
    func dstFallBack() {
        // November 1, 2026 is when DST ends in North America
        let result = jxaLocalDateExpr("2026-11-01")
        #expect(result == "new Date(\"2026-11-01T00:00:00\")")
    }

    // MARK: - jxaLocalEndDateExpr logic

    /// Mirrors the helper's `jxaLocalEndDateExpr` — must stay in sync.
    private func jxaLocalEndDateExpr(_ iso: String) -> String {
        func jxaEscape(_ s: String) -> String {
            s.replacingOccurrences(of: "\\", with: "\\\\")
             .replacingOccurrences(of: "\"", with: "\\\"")
             .replacingOccurrences(of: "\n", with: "\\n")
             .replacingOccurrences(of: "\r", with: "\\r")
             .replacingOccurrences(of: "\t", with: "\\t")
        }
        let safe = jxaEscape(iso)
        if safe.contains("T") {
            return "new Date(\"\(safe)\")"
        }
        return "(function(){ var d = new Date(\"\(safe)T00:00:00\"); d.setDate(d.getDate()+1); return d; })()"
    }

    @Test("End date-only string adds one day for full-day coverage")
    func endDateOnlyAddsOneDay() {
        let result = jxaLocalEndDateExpr("2026-03-10")
        #expect(result.contains("2026-03-10T00:00:00"))
        #expect(result.contains("setDate"))
    }

    @Test("End date with time is passed through unchanged")
    func endDateTimePassedThrough() {
        let result = jxaLocalEndDateExpr("2026-03-10T23:59:59")
        #expect(result == "new Date(\"2026-03-10T23:59:59\")")
    }

    @Test("Same start and end date-only produces different expressions")
    func sameStartEndDateProducesDifferentRange() {
        let start = jxaLocalDateExpr("2026-03-10")
        let end = jxaLocalEndDateExpr("2026-03-10")
        // Start is midnight March 10, end is midnight March 11
        #expect(start != end)
        #expect(start == "new Date(\"2026-03-10T00:00:00\")")
        #expect(end.contains("setDate"))
    }

    // MARK: - Calendar name trimming logic

    @Test("Trimmed comparison matches calendar with trailing space")
    func trimmedCalendarNameMatch() {
        let calendarName = "La vida del amor "
        let searchName = "La vida del amor"
        #expect(calendarName.trimmingCharacters(in: .whitespaces) == searchName)
    }

    @Test("Trimmed comparison matches calendar with no trailing space")
    func trimmedCalendarNameExactMatch() {
        let calendarName = "Home"
        let searchName = "Home"
        #expect(calendarName.trimmingCharacters(in: .whitespaces) == searchName)
    }

    @Test("Trimmed comparison handles leading and trailing whitespace")
    func trimmedCalendarNameBothSides() {
        let calendarName = " Work "
        let searchName = "Work"
        #expect(calendarName.trimmingCharacters(in: .whitespaces) == searchName)
    }
}
