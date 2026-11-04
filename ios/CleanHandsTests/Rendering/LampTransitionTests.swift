import Testing
@testable import CleanHands

/// 002 contracts/lamp-transition.md §10, checks L1–L4, plus the badge, freeze, and reset rules.
struct LampTransitionTests {
    private func switchOn(fps: Double, reduceMotion: Bool = false) -> (t99: Double, lamp: LampTransition) {
        var lamp = LampTransition()
        lamp.reduceMotion = reduceMotion
        lamp.setTarget(1, animated: true)
        var t = 0.0
        while lamp.uvAmount < 0.99, t < 3 {
            lamp.step(dt: 1 / fps)
            t += 1 / fps
        }
        return (t, lamp)
    }

    // L1
    @Test(arguments: [60.0, 30.0])
    func fullSwitchTakesPointEightSeconds(fps: Double) {
        #expect(abs(switchOn(fps: fps).t99 - 0.80) <= 0.02 + 1 / fps)
    }

    @Test(arguments: [60.0, 30.0])
    func reduceMotionSwitchIsDoneAtPointSix(fps: Double) {
        #expect(abs(switchOn(fps: fps, reduceMotion: true).t99 - 0.60) <= 0.02 + 1 / fps)
    }

    // Channels
    @Test func channelsAreOrderedBothWays() {
        for reduce in [false, true] {
            for i in 0...1000 {
                let c = LampTransition.channels(Float(i) / 1000, reduceMotion: reduce)
                if c.gate > 0 { #expect(c.skin == 1 && c.dark == 1, "a=\(i) reduce=\(reduce)") }
            }
            let zero = LampTransition.channels(0, reduceMotion: reduce)
            let one = LampTransition.channels(1, reduceMotion: reduce)
            #expect(zero.dark == 0 && zero.skin == 0 && zero.gate == 0)
            #expect(one.dark == 1 && one.skin == 1 && one.gate == 1)
        }
    }

    // L2
    @Test func randomRunsStayUnderTheBrightnessBound() {
        var rng = SplitMix64(seed: 2026_11_04)
        var worstDark: Float = 0, worstSkin: Float = 0
        for _ in 0..<400 {
            let fps = Double(rng.uniform(24...60))
            let reversals = Set((0..<rng.index(11)).map { _ in 1 + rng.index(200) })
            var lamp = LampTransition()
            lamp.setTarget(1, animated: true)
            var previous = LampTransition.channels(0, reduceMotion: false)
            for frame in 0..<300 {
                if reversals.contains(frame) { lamp.setTarget(lamp.uvTarget == 1 ? 0 : 1, animated: true) }
                lamp.step(dt: rng.unit() < 0.05 ? 3 / fps : 1 / fps)
                let c = LampTransition.channels(lamp.uvAmount, reduceMotion: false)
                worstDark = max(worstDark, abs(c.dark - previous.dark))
                worstSkin = max(worstSkin, abs(c.skin - previous.skin))
                previous = c
            }
        }
        #expect(worstDark <= 0.09, "dark \(worstDark)")
        #expect(worstSkin <= 0.11, "skin \(worstSkin)")
    }

    // L3
    @Test(arguments: [60.0, 30.0])
    func switchOffRemovesGlowBeforeSkin(fps: Double) {
        var (_, lamp) = switchOn(fps: fps)
        for _ in 0..<60 { lamp.step(dt: 1 / fps) }
        lamp.setTarget(0, animated: true)
        var glowGoneFrame: Int?
        var skinMovedFrame: Int?
        for frame in 0..<120 {
            lamp.step(dt: 1 / fps)
            let c = LampTransition.channels(lamp.uvAmount, reduceMotion: false)
            if glowGoneFrame == nil, c.gate == 0 { glowGoneFrame = frame }
            if skinMovedFrame == nil, c.skin < 1 { skinMovedFrame = frame }
        }
        #expect(glowGoneFrame != nil && skinMovedFrame != nil)
        #expect((glowGoneFrame ?? .max) < (skinMovedFrame ?? .min))
    }

    // L4
    @Test(arguments: [60.0, 30.0])
    func retargetingEveryFrameNeverJumps(fps: Double) {
        var lamp = LampTransition()
        lamp.setTarget(1, animated: true)
        var previous: Float = 0
        for frame in 0..<120 {
            if frame > 10 { lamp.setTarget(lamp.uvTarget == 1 ? 0 : 1, animated: true) }
            lamp.step(dt: 1 / fps)
            #expect(abs(lamp.uvAmount - previous) <= Float(1 / fps) / LampTransition.rampSeconds + 0.002)
            previous = lamp.uvAmount
        }
    }

    @Test func aReversalKeepsVelocityForSeveralFrames() {
        var lamp = LampTransition()
        lamp.setTarget(1, animated: true)
        for _ in 0..<20 { lamp.step(dt: 1.0 / 60) }
        let before = lamp.uvAmount
        lamp.setTarget(0, animated: true)
        #expect(lamp.uvAmount == before, "a retarget never moves the value on screen")
        var frames = 0
        while lamp.velocity > 0, frames < 100 {
            lamp.step(dt: 1.0 / 60)
            frames += 1
        }
        #expect(frames >= 3)
    }

    // Edges, badge, freeze, reset
    @Test func onlyAnAnimatedSwitchOnReportsAnEdge() {
        var lamp = LampTransition()
        let on = lamp.setTarget(1, animated: true)
        let again = lamp.setTarget(1, animated: true)
        let off = lamp.setTarget(0, animated: true)
        let snap = lamp.setTarget(1, animated: false)
        #expect(on)
        #expect(!again, "no edge without a change")
        #expect(!off, "switch-off never clicks")
        #expect(!snap, "snaps never click")
    }

    @Test func badgeIsRequiredFromTheSwitchUntilTheLampIsBackAtZero() {
        var lamp = LampTransition()
        #expect(!lamp.badgeRequired)
        lamp.setTarget(1, animated: true)
        #expect(lamp.badgeRequired, "rises in the same call as the switch")
        for _ in 0..<60 { lamp.step(dt: 1.0 / 60) }
        lamp.setTarget(0, animated: true)
        #expect(lamp.badgeRequired)
        for _ in 0..<90 { lamp.step(dt: 1.0 / 60) }
        #expect(lamp.uvAmount == 0)
        #expect(!lamp.badgeRequired)
    }

    @Test func frozenLampHoldsAndResumesWithoutAnEdge() {
        var lamp = LampTransition()
        lamp.setTarget(1, animated: true)
        for _ in 0..<20 { lamp.step(dt: 1.0 / 60) }
        lamp.frozen = true
        let held = lamp
        for _ in 0..<60 { lamp.step(dt: 1.0 / 60) }
        #expect(lamp == held)
        let edge = lamp.setTarget(1, animated: true)
        #expect(!edge)
        lamp.frozen = false
        lamp.step(dt: 1.0 / 60)
        #expect(lamp.uvAmount > held.uvAmount)
    }

    @Test func interlockFollowsTheBadge() {
        var (_, lamp) = switchOn(fps: 60)
        #expect(lamp.glowInterlock == 0, "no glow until the badge is opaque")
        lamp.badgeOpaque = true
        for _ in 0..<13 { lamp.step(dt: 1.0 / 60) }
        #expect(lamp.glowInterlock == 1)
        lamp.badgeOpaque = false
        lamp.step(dt: 1.0 / 60)
        #expect(lamp.glowInterlock == 0)
    }

    @Test func resetReturnsToTheCameraWithTheSpreadUnplayed() {
        var (_, lamp) = switchOn(fps: 60)
        for _ in 0..<120 { lamp.step(dt: 1.0 / 60) }
        #expect(lamp.spreadPlayed)
        lamp.reset()
        #expect(lamp.uvAmount == 0 && lamp.uvTarget == 0 && !lamp.spreadPlayed)
    }
}
