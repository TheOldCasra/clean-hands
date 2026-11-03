import simd

/// Keeps each hand's identity and handedness stable across frames (research R5 fallback). A hand
/// gets its handedness once per appearance: from the tracker's chirality when known, otherwise
/// from its position. Later chirality flips are ignored until the hand leaves the view.
struct HandIdentity: Sendable {
    struct Assignment: Sendable, Equatable {
        var id: Int
        var handedness: Handedness
        var isNew: Bool
    }

    /// A hand that moves further than this (in scales) between frames counts as a new hand.
    var maxJump: Float = 1.5
    /// Whether the image is mirrored, so that "left side of the image" maps to the right hand.
    var mirrored: Bool = false

    private struct Track: Sendable {
        var id: Int
        var handedness: Handedness
        var wrist: SIMD2<Float>
    }

    private var tracks: [Track] = []
    private var nextID = 0

    mutating func assign(_ hands: [RawHand], imageWidth: Float) -> [Assignment] {
        var remaining = tracks
        var result: [Assignment] = []
        var updated: [Track] = []

        for hand in hands {
            let wrist = hand.joints[Joint.wrist.rawValue].position
            let scale = max(TrackedHand.scale(of: hand.joints), 1)
            let nearest = remaining.enumerated()
                .map { ($0.offset, simd_distance($0.element.wrist, wrist)) }
                .min { $0.1 < $1.1 }
            if let (index, distance) = nearest, distance <= maxJump * scale {
                var track = remaining.remove(at: index)
                track.wrist = wrist
                updated.append(track)
                result.append(Assignment(id: track.id, handedness: track.handedness, isNew: false))
            } else {
                let track = Track(id: nextID, handedness: initialHandedness(hand, among: hands, imageWidth: imageWidth), wrist: wrist)
                nextID += 1
                updated.append(track)
                result.append(Assignment(id: track.id, handedness: track.handedness, isNew: true))
            }
        }

        // Two hands must not share a pattern: resolve a clash by image position.
        if result.count == 2, result[0].handedness == result[1].handedness {
            let xs = hands.map { $0.joints[Joint.wrist.rawValue].position.x }
            let leftOnImage = xs[0] < xs[1] ? 0 : 1
            let imageLeftHand: Handedness = mirrored ? .right : .left
            for i in 0..<2 {
                let handedness: Handedness = i == leftOnImage ? imageLeftHand.opposite : imageLeftHand
                result[i].handedness = handedness
                updated[i].handedness = handedness
            }
        }

        tracks = updated
        return result
    }

    private func initialHandedness(_ hand: RawHand, among hands: [RawHand], imageWidth: Float) -> Handedness {
        switch hand.chirality {
        case .left: return .left
        case .right: return .right
        case .unknown:
            // Palms up in front of the participant: her right hand is on the image's right
            // (overhead rear camera, unmirrored).
            let x = hand.joints[Joint.wrist.rawValue].position.x
            let others = hands.map { $0.joints[Joint.wrist.rawValue].position.x }
            let isLeftmost = others.allSatisfy { x <= $0 }
            let onImageLeft = hands.count > 1 ? isLeftmost : x < imageWidth / 2
            return onImageLeft != mirrored ? .left : .right
        }
    }

    mutating func reset() {
        tracks = []
    }
}

extension Handedness {
    var opposite: Handedness { self == .left ? .right : .left }
}
