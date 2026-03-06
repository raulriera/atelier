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

    @Test @MainActor func consecutiveFailuresMarkUnavailable() {
        let monitor = CapabilityHealthMonitor()
        var lastAlert: String?
        for _ in 0..<3 {
            lastAlert = monitor.recordFailure(toolName: "mcp__atelier-mail__mail_search_messages")
        }
        #expect(monitor.health["mail"] == .unavailable)
        #expect(lastAlert != nil)
        #expect(lastAlert?.contains("unavailable") == true)
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

    @Test @MainActor func successAfterFailuresRestoresHealth() {
        let monitor = CapabilityHealthMonitor()
        _ = monitor.recordFailure(toolName: "mcp__atelier-calendar__calendar_create_event")
        _ = monitor.recordFailure(toolName: "mcp__atelier-calendar__calendar_create_event")
        #expect(monitor.health["calendar"] == .degraded)

        monitor.recordSuccess(toolName: "mcp__atelier-calendar__calendar_list_events")
        #expect(monitor.health["calendar"] == .degraded) // still has failures in window
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
