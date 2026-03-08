import Foundation
import Testing
@testable import AtelierKit

@Suite("LaunchAgentManager")
struct LaunchAgentManagerTests {

    // MARK: - plistURL

    @Test func plistURLPointsToCorrectLocation() {
        let manager = LaunchAgentManager()
        let expected = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/com.atelier.scheduler.plist")

        #expect(manager.plistURL == expected)
    }

    // MARK: - buildPlist

    @Test func buildPlistHasCorrectLabel() {
        let manager = LaunchAgentManager()
        let plist = manager.buildPlist(calendarIntervals: [["Minute": 0]])

        #expect(plist["Label"] as? String == "com.atelier.scheduler")
    }

    @Test func buildPlistHasAssociatedBundleIdentifiers() {
        let manager = LaunchAgentManager()
        let plist = manager.buildPlist(calendarIntervals: [["Minute": 0]])

        let identifiers = plist["AssociatedBundleIdentifiers"] as? [String]
        #expect(identifiers == ["com.atelier"])
    }

    @Test func buildPlistHasProgramArguments() throws {
        let manager = LaunchAgentManager()
        let plist = manager.buildPlist(calendarIntervals: [["Minute": 0]])

        let args = try #require(plist["ProgramArguments"] as? [String])
        #expect(args.count == 1)
        #expect(args.first?.hasSuffix("Contents/Helpers/atelier-scheduler") == true)
    }

    @Test func buildPlistHasStartCalendarInterval() throws {
        let manager = LaunchAgentManager()
        let intervals: [[String: Int]] = [
            ["Hour": 8, "Minute": 0],
            ["Weekday": 1, "Hour": 15, "Minute": 0],
        ]
        let plist = manager.buildPlist(calendarIntervals: intervals)

        let stored = try #require(plist["StartCalendarInterval"] as? [[String: Int]])
        #expect(stored.count == 2)
        #expect(stored[0] == ["Hour": 8, "Minute": 0])
        #expect(stored[1] == ["Weekday": 1, "Hour": 15, "Minute": 0])
    }

    @Test func buildPlistHasLogPaths() throws {
        let manager = LaunchAgentManager()
        let plist = manager.buildPlist(calendarIntervals: [["Minute": 0]])

        let stdout = try #require(plist["StandardOutPath"] as? String)
        let stderr = try #require(plist["StandardErrorPath"] as? String)
        #expect(stdout.hasSuffix("Library/Logs/Atelier/scheduler.log"))
        #expect(stderr.hasSuffix("Library/Logs/Atelier/scheduler.err"))
    }

    @Test func buildPlistHasWorkingDirectory() {
        let manager = LaunchAgentManager()
        let plist = manager.buildPlist(calendarIntervals: [["Minute": 0]])

        #expect(plist["WorkingDirectory"] as? String == "/tmp")
    }

    @Test func buildPlistWithSingleInterval() {
        let manager = LaunchAgentManager()
        let plist = manager.buildPlist(calendarIntervals: [["Hour": 12, "Minute": 30]])

        let stored = plist["StartCalendarInterval"] as? [[String: Int]]
        #expect(stored?.count == 1)
        #expect(stored?.first == ["Hour": 12, "Minute": 30])
    }

    @Test func buildPlistSerializesToValidPropertyList() throws {
        let manager = LaunchAgentManager()
        let plist = manager.buildPlist(calendarIntervals: [["Minute": 0]])

        // Verify it can be serialized as a plist without error
        let data = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
        #expect(!data.isEmpty)
    }
}
