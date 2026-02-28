import Testing
@testable import AtelierDesign

@Test func radiiValues() {
    #expect(Radii.sm == 6)
    #expect(Radii.md == 10)
    #expect(Radii.lg == 16)
}

@Test func radiiMonotonicallyIncreasing() {
    #expect(Radii.sm < Radii.md)
    #expect(Radii.md < Radii.lg)
}
