# Contract: `look.json` (visual tuning file)

All visual parameters live in one bundled JSON file, so matching the owner's references
(`docs/reference/`) is tuning, not coding. A debug-only tuning panel can edit these values live
and save a new `look.json`. Release builds read the bundled file only.

Defaults below come from the reference measurements (see `docs/reference/README.md`) and from
research R6–R7. Colors are sRGB hex.

```json
{
  "version": 1,
  "uvView": {
    "background": "#000000",
    "skinRamp": ["#000000", "#1f192f", "#2e2a3a", "#3d3656"],
    "skinTargetValue": 0.24,
    "skinLocalContrast": 0.35,
    "lightPool": { "dilate": 0.15, "blur": 0.25, "falloff": 0.6 },
    "nailTint": { "color": "#b8b0e0", "strength": 0.15 }
  },
  "glow": {
    "palette": { "low": "#508661", "mid": "#5a7c55", "high": "#8dce7b", "peak": "#80df90" },
    "hueJitter": 0.08,
    "grain": { "scale": 0.012, "strength": 0.55 },
    "skinDetailStrength": 0.45,
    "bloom": { "radius": 0.006, "intensity": 0.12 },
    "coverageTarget": { "min": 0.15, "max": 0.25 }
  },
  "pattern": {
    "caps": { "extent": [0.55, 0.9], "brightness": [0.7, 1.0] },
    "counts": { "streak": 24, "fleck": 220, "patch": 9 },
    "regionWeights": {
      "fingertip": 6.0, "thumb": 3.0, "interdigital": 2.5, "backOfHand": 2.0,
      "palmEdge": 2.0, "wrist": 1.5, "dorsalFinger": 1.5, "palm": 1.0
    },
    "leftRightMaxDiff": 0.10,
    "wristExtent": 0.25
  },
  "fade": {
    "quickRinse": { "palm": 0.3 },
    "wristPerRehearsal": 0.5,
    "fadeInMs": 300,
    "fadeOutMs": 250
  },
  "rehearsal": { "stepSeconds": [4, 5, 4, 4, 4, 4], "pauseAfterMs": 1000 },
  "quality": {
    "high":   { "countScale": 1.0, "bloomScale": 0.5 },
    "medium": { "countScale": 0.7, "bloomScale": 0.25 },
    "low":    { "countScale": 0.45, "bloomScale": 0.0 }
  }
}
```

## Units

- Distances (`dilate`, `blur`, `radius`, `scale`, `wristExtent`) are fractions of the hand's `scale`: the
  wrist to middle-finger knuckle distance.
- Counts are per hand side at quality `high`.
- `fade.quickRinse.palm` is the multiplier left after the demo (0.3 = 70% faded).

## Visual QA (constitution gate 3)

Pass when, in side-by-side screenshots of the app (open palm, and two cupped hands, under the
session lighting) next to `ref-01` and `ref-02`, all of the following hold:

1. **Background**: near-black. The skin reads as dark violet with creases visible.
2. **Glow color**: lime-to-mint green, with no yellow or cyan cast.
3. **Coverage**: 15–25% of the visible hand. Fingertips are clearly dominant, and the palm
   centre is mostly clean (measured with the same script as the references).
4. **Texture**: the glow looks powdery and broken by skin creases, not like smooth blobs or
   confetti.
5. **Halo**: little or none.
6. **Reviewers**: at least 2 of 3 reviewers (owner, plus 2 partner staff) say "looks like the
   reference".

Constitution Principle II applies here too. QA screenshots are taken only of consenting test
volunteers' hands and are never taken during participant sessions.
