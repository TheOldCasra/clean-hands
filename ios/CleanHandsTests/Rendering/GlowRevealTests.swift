import Testing
@testable import CleanHands

/// 002 contracts/lamp-transition.md §5, check L5.
struct GlowRevealTests {
    private func mark(_ anchor: Anchor) -> GlowMark {
        GlowMark(hand: .right, surface: .palm, region: .fingertip, anchor: anchor, kind: .fleck,
                 size: 0.02, aspect: 1, intensity: 1, hue: 0.5, grainSeed: 0)
    }

    @Test func orderRisesFromFingertipToForearm() {
        let points: [Anchor] = [
            .bone(a: 11, b: 12, t: 1, s: 0),   // middle tip
            .bone(a: 10, b: 11, t: 1, s: 0),   // DIP
            .bone(a: 9, b: 10, t: 1, s: 0),    // PIP
            .bone(a: 9, b: 10, t: 0, s: 0),    // MCP
            .triangle(a: 0, b: 9, c: 13, u: 1, v: 0, w: 0), // wrist
            .bone(a: 0, b: Joint.forearm, t: 1, s: 0),       // forearm point
        ]
        let orders = points.map { Anchoring.revealOrder(of: mark($0), wristExtent: 0.25) }
        #expect(orders == orders.sorted())
        #expect(orders.first == 0)
        #expect(orders.last == 1)
        #expect(orders.allSatisfy { (0...1).contains($0) })
    }

    @Test func thumbFollowsTheSameChain() {
        let tip = Anchoring.revealOrder(of: mark(.bone(a: 3, b: 4, t: 1, s: 0)), wristExtent: 0.25)
        let base = Anchoring.revealOrder(of: mark(.bone(a: 1, b: 2, t: 0, s: 0)), wristExtent: 0.25)
        #expect(tip == 0)
        #expect(abs(base - 1 / 2.25) < 1e-6)
    }

    @Test func everyMarkIsFullyRevealedAtTheEnd() throws {
        let look = try bundledLook()
        let pattern = PatternGenerator.generate(seed: 42, config: look)
        for m in pattern.marks {
            let order = Anchoring.revealOrder(of: m, wristExtent: Float(look.pattern.wristExtent))
            #expect(LampTransition.revealFactor(order: order, glowReveal: 1) == 1)
            #expect(LampTransition.revealFactor(order: order, glowReveal: 0) == 0)
        }
    }

    @Test func fingertipsLightBeforeTheWrist() {
        let tip = LampTransition.revealFactor(order: 0, glowReveal: 0.3)
        let wrist = LampTransition.revealFactor(order: 2 / 2.25, glowReveal: 0.3)
        #expect(tip > 0.9)
        #expect(wrist == 0)
    }

    @Test func spreadPlaysOncePerSession() {
        var lamp = LampTransition()
        lamp.setTarget(1, animated: true)
        for _ in 0..<200 { lamp.step(dt: 1.0 / 60) }
        #expect(lamp.glowReveal == 1)
        lamp.setTarget(0, animated: true)
        for _ in 0..<90 { lamp.step(dt: 1.0 / 60) }
        lamp.setTarget(1, animated: true)
        lamp.step(dt: 1.0 / 60)
        #expect(lamp.glowReveal == 1, "later switch-ons return through the gate, no spread")
    }

    @Test func reduceMotionSkipsTheSpread() {
        var lamp = LampTransition()
        lamp.reduceMotion = true
        lamp.setTarget(1, animated: true)
        var sawPartial = false
        for _ in 0..<60 {
            lamp.step(dt: 1.0 / 60)
            if lamp.glowReveal > 0, lamp.glowReveal < 1 { sawPartial = true }
        }
        #expect(!sawPartial)
        #expect(lamp.glowReveal == 1)
    }

    @Test func switchingOffMidSpreadCountsAsPlayed() {
        var lamp = LampTransition()
        lamp.setTarget(1, animated: true)
        for _ in 0..<70 { lamp.step(dt: 1.0 / 60) }
        #expect(lamp.glowReveal > 0 && lamp.glowReveal < 1)
        lamp.setTarget(0, animated: true)
        for _ in 0..<90 { lamp.step(dt: 1.0 / 60) }
        #expect(lamp.glowReveal == 1)
    }
}
