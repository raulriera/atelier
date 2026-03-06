import Foundation
import Testing
@testable import AtelierKit

@Suite("CapabilityHealthMonitor")
struct CapabilityHealthMonitorTests {

    @Test @MainActor func successKeepsHealthy() {
        let monitor = CapabilityHealthMonitor()
        monitor.recordSuccess(toolName: "mcp__atelier-calendar__calendar_list_events")
        #expect(monitor.health["calendar"] == .healthy)
    }

    @Test @MainActor func singleFailureMarksDegraded() {
        let monitor = CapabilityHealthMonitor()
        let alert = monitor.recordFailure(toolName: "mcp__atelier-calendar__calendar_create_event")
        #expect(monitor.health["calendar"] == .degraded)
        #expect(alert == nil)
    }

    @Test @MainActor func consecutiveFailuresMarkUnavailable() throws {
        let monitor = CapabilityHealthMonitor()
        var lastAlert: String?
        for _ in 0..<3 {
            lastAlert = monitor.recordFailure(toolName: "mcp__atelier-mail__mail_search_messages")
        }
        #expect(monitor.health["mail"] == .unavailable)
        let alert = try #require(lastAlert)
        #expect(alert.contains("unavailable"))
    }

    @Test @MainActor func alertOnlyFiredOnce() {
        let monitor = CapabilityHealthMonitor()
        for _ in 0..<3 {
            _ = monitor.recordFailure(toolName: "mcp__atelier-mail__mail_search_messages")
        }

        // Further failures should not produce another alert
        let alert = monitor.recordFailure(toolName: "mcp__atelier-mail__mail_search_messages")
        #expect(alert == nil)
    }

    @Test @MainActor func successWithRemainingFailuresStaysDegraded() {
        let monitor = CapabilityHealthMonitor()
        _ = monitor.recordFailure(toolName: "mcp__atelier-calendar__calendar_create_event")
        _ = monitor.recordFailure(toolName: "mcp__atelier-calendar__calendar_create_event")
        #expect(monitor.health["calendar"] == .degraded)

        // One success doesn't clear the failures still in the window
        monitor.recordSuccess(toolName: "mcp__atelier-calendar__calendar_list_events")
        #expect(monitor.health["calendar"] == .degraded)
    }

    @Test @MainActor func enoughSuccessesRestoreHealth() {
        let monitor = CapabilityHealthMonitor()
        _ = monitor.recordFailure(toolName: "mcp__atelier-calendar__calendar_create_event")
        _ = monitor.recordFailure(toolName: "mcp__atelier-calendar__calendar_create_event")
        #expect(monitor.health["calendar"] == .degraded)

        // Push failures out of the sliding window with successes
        for _ in 0..<5 {
            monitor.recordSuccess(toolName: "mcp__atelier-calendar__calendar_list_events")
        }
        #expect(monitor.health["calendar"] == .healthy)
    }

    @Test @MainActor func failuresForOneCapabilityDontAffectAnother() {
        let monitor = CapabilityHealthMonitor()
        for _ in 0..<3 {
            _ = monitor.recordFailure(toolName: "mcp__atelier-calendar__calendar_create_event")
        }
        monitor.recordSuccess(toolName: "mcp__atelier-mail__mail_search_messages")

        #expect(monitor.health["calendar"] == .unavailable)
        #expect(monitor.health["mail"] == .healthy)
    }

    @Test @MainActor func alertFiresAgainAfterReset() {
        let monitor = CapabilityHealthMonitor()
        for _ in 0..<3 {
            _ = monitor.recordFailure(toolName: "mcp__atelier-mail__mail_search_messages")
        }
        #expect(monitor.health["mail"] == .unavailable)

        monitor.reset()

        // After reset, the same capability should alert again
        var alert: String?
        for _ in 0..<3 {
            alert = monitor.recordFailure(toolName: "mcp__atelier-mail__mail_search_messages")
        }
        #expect(alert != nil)
    }

    @Test @MainActor func resetClearsEverything() {
        let monitor = CapabilityHealthMonitor()
        for _ in 0..<3 {
            _ = monitor.recordFailure(toolName: "mcp__atelier-mail__mail_search_messages")
        }

        monitor.reset()
        #expect(monitor.health.isEmpty)
    }

    @Test @MainActor func nonMCPToolNameIsIgnored() {
        let monitor = CapabilityHealthMonitor()
        let alert = monitor.recordFailure(toolName: "Bash")
        #expect(monitor.health.isEmpty)
        #expect(alert == nil)
    }
}
