import Foundation
import Testing
@testable import AtelierSecurity

@Suite("BackupStatus")
struct BackupStatusTests {

    @Test func initializesWithAllProperties() {
        let date = Date()
        let status = BackupStatus(
            isConfigured: true,
            lastBackupDate: date,
            recommendation: .proceed
        )

        #expect(status.isConfigured)
        #expect(status.lastBackupDate == date)
        #expect(status.recommendation == .proceed)
    }

    @Test func handlesNotConfigured() {
        let status = BackupStatus(
            isConfigured: false,
            lastBackupDate: nil,
            recommendation: .noBackupConfigured
        )

        #expect(!status.isConfigured)
        #expect(status.lastBackupDate == nil)
        #expect(status.recommendation == .noBackupConfigured)
    }

    @Test func backupRecommendationRawValues() {
        #expect(BackupRecommendation.proceed.rawValue == "proceed")
        #expect(BackupRecommendation.warn.rawValue == "warn")
        #expect(BackupRecommendation.noBackupConfigured.rawValue == "noBackupConfigured")
    }
}
