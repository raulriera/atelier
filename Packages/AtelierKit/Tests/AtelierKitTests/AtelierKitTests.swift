import Testing
@testable import AtelierKit

@Test("Package version is set correctly")
func version() {
    #expect(AtelierKit.version == "0.1.0")
}
