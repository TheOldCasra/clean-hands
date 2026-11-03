/// Generates a participant's glow pattern from her seed (research R7). The same seed and config
/// always give the same marks (FR-006). Both hands get the same number of marks per region, so
/// left and right are balanced by construction (FR-004); only positions differ.
enum PatternGenerator {
    /// Approximate skin area of each region on one side of a hand, in scale². Together with the
    /// region weights this sets how many streaks, flecks, and patches each region gets.
    static func area(_ region: GlowRegion, side: PatternSide) -> Double {
        switch (region, side) {
        case (.fingertip, _): 0.19
        case (.thumb, _): 0.15
        case (.interdigital, _): 0.27
        case (.wrist, _): 0.15
        case (.palm, .palm): 0.75
        case (.palmEdge, .palm): 0.25
        case (.dorsalFinger, .back): 0.25
        case (.backOfHand, .back): 0.75
        default: 0
        }
    }

    static func regions(for kind: MarkKind, side: PatternSide) -> [GlowRegion] {
        switch (kind, side) {
        case (.cap, _): [.fingertip]
        case (.streak, .palm): [.fingertip, .thumb, .interdigital, .palm]
        case (.streak, .back): [.fingertip, .thumb, .interdigital, .dorsalFinger]
        case (.fleck, .palm): [.fingertip, .thumb, .interdigital, .palm, .palmEdge, .wrist]
        case (.fleck, .back): [.fingertip, .thumb, .interdigital, .dorsalFinger, .backOfHand, .wrist]
        case (.patch, .palm): [.palmEdge, .thumb, .wrist]
        case (.patch, .back): [.backOfHand, .interdigital, .thumb, .wrist]
        }
    }

    /// Splits `total` marks over regions in proportion to weight × area (largest remainder).
    static func allocate(_ total: Int, kind: MarkKind, side: PatternSide, config: LookConfig) -> [(GlowRegion, Int)] {
        let regions = regions(for: kind, side: side)
        let shares = regions.map { config.weight(for: $0) * area($0, side: side) }
        let sum = shares.reduce(0, +)
        guard sum > 0, total > 0 else { return regions.map { ($0, 0) } }
        let exact = shares.map { Double(total) * $0 / sum }
        var counts = exact.map { Int($0) }
        let order = exact.indices.sorted { (exact[$0] - Double(counts[$0])) > (exact[$1] - Double(counts[$1])) }
        for i in order.prefix(total - counts.reduce(0, +)) {
            counts[i] += 1
        }
        return Array(zip(regions, counts))
    }

    static func generate(seed: UInt64, config: LookConfig) -> GlowPattern {
        var marks: [GlowMark] = []
        for (h, hand) in Handedness.allCases.enumerated() {
            for (s, side) in PatternSide.allCases.enumerated() {
                var rng = SplitMix64(seed: seed ^ (0x5DEE_CE66_D1CE_4E5B &* UInt64(1 + h * 2 + s)))
                marks += generateSide(hand: hand, side: side, config: config, rng: &rng)
            }
        }
        return GlowPattern(seed: seed, marks: marks)
    }

    private static func generateSide(hand: Handedness, side: PatternSide, config: LookConfig, rng: inout SplitMix64) -> [GlowMark] {
        var marks: [GlowMark] = []
        let caps = config.pattern.caps

        func mark(_ region: GlowRegion, _ anchor: Anchor, _ kind: MarkKind, size: Float, aspect: Float, intensity: Float) -> GlowMark {
            GlowMark(hand: hand, surface: side, region: region, anchor: anchor, kind: kind, size: size, aspect: aspect,
                     intensity: intensity, hue: rng.unit(), grainSeed: UInt32(truncatingIfNeeded: rng.next()))
        }

        // One cap per finger and thumb.
        for tip in [4, 8, 12, 16, 20] {
            let extent = rng.uniform(Float(caps.extent[0])...Float(caps.extent[1]))
            let brightness = rng.uniform(Float(caps.brightness[0])...Float(caps.brightness[1]))
            marks.append(mark(.fingertip, .bone(a: tip - 1, b: tip, t: 1 - extent / 2, s: 0), .cap, size: extent, aspect: 1, intensity: brightness))
        }

        let counts = config.pattern.counts
        for (kind, total) in [(MarkKind.streak, counts.streak), (.fleck, counts.fleck), (.patch, counts.patch)] {
            for (region, count) in allocate(total, kind: kind, side: side, config: config) {
                for _ in 0..<count {
                    let anchor = sampleAnchor(region: region, kind: kind, side: side, rng: &rng)
                    let (size, aspect, intensity) = sampleShape(kind, rng: &rng)
                    marks.append(mark(region, anchor, kind, size: size, aspect: aspect, intensity: intensity))
                }
            }
        }
        return marks
    }

    private static func sampleShape(_ kind: MarkKind, rng: inout SplitMix64) -> (Float, Float, Float) {
        switch kind {
        case .cap: (1, 1, 1)
        case .streak: (rng.uniform(0.025...0.045), rng.uniform(2.5...4.0), rng.uniform(0.55...0.9))
        case .fleck: (rng.uniform(0.01...0.025), rng.uniform(1.0...1.6), rng.uniform(0.45...0.85))
        case .patch: (rng.uniform(0.12...0.2), rng.uniform(1.0...1.6), rng.uniform(0.1...0.22))
        }
    }

    // MARK: - Anchors per region

    private static func sampleAnchor(region: GlowRegion, kind: MarkKind, side: PatternSide, rng: inout SplitMix64) -> Anchor {
        let fingerBases = [5, 9, 13, 17]
        switch region {
        case .fingertip:
            let tip = [4, 8, 12, 16, 20][rng.index(5)]
            return .bone(a: tip - 1, b: tip, t: rng.unit(), s: rng.uniform(-0.7...0.7))
        case .thumb:
            if kind == .patch {
                // Base of the thumb.
                return .bone(a: 1, b: 2, t: rng.uniform(0.1...0.4), s: rng.uniform(-0.3...0.3))
            }
            // Mostly the outer thumb bone: the part a quick wash misses most.
            let bone = rng.unit() < 0.7 ? 1 : 0
            return .bone(a: 1 + bone, b: 2 + bone, t: rng.unit(), s: rng.uniform(-0.7...0.7))
        case .interdigital:
            let base = fingerBases[rng.index(4)]
            let segment = rng.index(2)
            let s = rng.uniform(0.4...0.7) * (rng.unit() < 0.5 ? -1 : 1)
            return .bone(a: base + segment, b: base + segment + 1, t: rng.uniform(0.25...1), s: s)
        case .dorsalFinger:
            let base = fingerBases[rng.index(4)]
            let segment = rng.index(2)
            return .bone(a: base + segment, b: base + segment + 1, t: rng.unit(), s: rng.uniform(-0.4...0.4))
        case .palm:
            // Palm centre, or the middle of the palmar finger segments (reached by palm-to-palm).
            // Streaks run along finger bones, so on the palm side they only go on the fingers.
            if kind == .streak || rng.unit() < 0.85 {
                let base = fingerBases[rng.index(4)]
                let segment = rng.index(2)
                return .bone(a: base + segment, b: base + segment + 1, t: rng.unit(), s: rng.uniform(-0.4...0.4))
            }
            return sampleTriangle(rng: &rng) { tri, u, v, w in
                !isPalmEdge(tri: tri, u: u, v: v, w: w)
            }
        case .palmEdge:
            return sampleTriangle(rng: &rng) { tri, u, v, w in
                isPalmEdge(tri: tri, u: u, v: v, w: w)
            }
        case .backOfHand:
            // Patches lean toward the knuckles and between the fingers (research R7).
            return sampleTriangle(rng: &rng) { _, u, _, _ in
                kind != .patch || u < 0.45
            }
        case .wrist:
            return .bone(a: Joint.wrist.rawValue, b: Joint.forearm, t: rng.unit(), s: rng.uniform(-0.7...0.7))
        }
    }

    /// The heel of the hand, and the little-finger edge of the palm.
    private static func isPalmEdge(tri: Int, u: Float, v: Float, w: Float) -> Bool {
        u > 0.72 || (tri == 3 && v < 0.35)
    }

    private static func sampleTriangle(rng: inout SplitMix64, accept: (Int, Float, Float, Float) -> Bool) -> Anchor {
        var last: Anchor?
        for _ in 0..<64 {
            let tri = rng.index(Anchoring.palmTriangles.count)
            let r1 = rng.unit().squareRoot()
            let r2 = rng.unit()
            let (u, v, w) = (1 - r1, r1 * (1 - r2), r1 * r2)
            let (a, b, c) = Anchoring.palmTriangles[tri]
            let anchor = Anchor.triangle(a: a, b: b, c: c, u: u, v: v, w: w)
            if accept(tri, u, v, w) { return anchor }
            last = anchor
        }
        return last!
    }
}
