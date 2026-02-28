import Testing
import SwiftUI
@testable import AtelierDesign

@MainActor
@Test func motionCurvesExist() {
    // Verify all motion curves are defined and accessible
    let _: Animation = Motion.appear
    let _: Animation = Motion.settle
    let _: Animation = Motion.streaming
    let _: Animation = Motion.morph
}

@MainActor
@Test func motionTransitionsExist() {
    // Verify all transitions are defined and accessible
    let _: AnyTransition = Motion.timelineInsert
    let _: AnyTransition = Motion.cardReveal
    let _: AnyTransition = Motion.approvalAppear
}
