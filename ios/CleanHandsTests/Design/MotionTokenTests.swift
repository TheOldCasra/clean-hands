import SwiftUI
import Testing
@testable import CleanHands

struct MotionTokenTests {
    @Test func everySpringIsCriticallyDamped() {
        #expect(Motion.damping == 1.0)
        #expect(Motion.standard == .spring(response: 0.35, dampingFraction: 1.0))
        #expect(Motion.quick == .spring(response: 0.2, dampingFraction: 1.0))
    }

    @Test func reduceMotionSelectsTheReducedEquivalent() {
        #expect(Motion.animation(.standard, reduceMotion: true) == Motion.reducedFade)
        #expect(Motion.animation(.quick, reduceMotion: true) == Motion.reducedFade)
        #expect(Motion.animation(.reducedFade, reduceMotion: false) == Motion.reducedFade)
        #expect(Motion.animation(.standard, reduceMotion: false) == Motion.standard)
        #expect(Motion.animation(.lamp, reduceMotion: true) == .linear(duration: 0.4))
    }

    @Test func rendererTimings() {
        #expect(Motion.lamp.seconds(reduceMotion: false) == 0.8)
        #expect(Motion.lamp.seconds(reduceMotion: true) == 0.4)
        #expect(Motion.glowSpread.seconds(reduceMotion: false) == 1.5)
        #expect(Motion.glowSpread.seconds(reduceMotion: true) == 0)
    }
}
