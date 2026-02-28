import Testing
@testable import AtelierDesign

@Test func spacingValues() {
    // All spacing values follow a 4-point grid
    #expect(Spacing.xxs == 4)
    #expect(Spacing.xs == 8)
    #expect(Spacing.sm == 12)
    #expect(Spacing.md == 16)
    #expect(Spacing.lg == 24)
    #expect(Spacing.xl == 32)
    #expect(Spacing.xxl == 48)
}

@Test func spacingGridAlignment() {
    // Every value should be divisible by 4 (our base grid unit)
    let values = [Spacing.xxs, Spacing.xs, Spacing.sm, Spacing.md, Spacing.lg, Spacing.xl, Spacing.xxl]
    for value in values {
        #expect(value.truncatingRemainder(dividingBy: 4) == 0, "Spacing \(value) is not on the 4pt grid")
    }
}

@Test func spacingMonotonicallyIncreasing() {
    let values = [Spacing.xxs, Spacing.xs, Spacing.sm, Spacing.md, Spacing.lg, Spacing.xl, Spacing.xxl]
    for i in 1..<values.count {
        #expect(values[i] > values[i - 1], "Spacing values must be monotonically increasing")
    }
}
