import Foundation
import Testing
@testable import AtelierSecurity

@Suite("FileOperationResult")
struct FileOperationResultTests {

    @Test func successCarriesRecord() {
        let record = FileOperationRecord(
            operation: .trash(URL(fileURLWithPath: "/tmp/test")),
            resultURL: URL(fileURLWithPath: "/.Trash/test")
        )
        let result = FileOperationResult.success(record)

        if case .success(let r) = result {
            #expect(r.resultURL?.path == "/.Trash/test")
        } else {
            Issue.record("Expected success")
        }
    }

    @Test func failureCarriesError() {
        let result = FileOperationResult.failure(
            .trash(URL(fileURLWithPath: "/missing")),
            .fileNotFound(URL(fileURLWithPath: "/missing"))
        )

        if case .failure(_, let error) = result {
            if case .fileNotFound(let url) = error {
                #expect(url.path == "/missing")
            } else {
                Issue.record("Expected fileNotFound")
            }
        } else {
            Issue.record("Expected failure")
        }
    }
}
