# Data Model: UV Germ Visualization Study MVP

**Feature**: `001-uv-germ-visualization` | **Date**: 2026-11-03 | **Plan**: [plan.md](plan.md)

Two kinds of data. **Study data** is stored on the iPad and exported (Participant, Session,
SessionEvent), or collected on paper (MeasureResponse). **Runtime data** lives in memory only:
HandFrame, GlowPattern, FadeState. No entity ever contains a camera image (Principle II).

## Study data

### Participant

| Field | Type | Rules |
|---|---|---|
| `code` | string | Pattern `^(ZNZ\|PIL)-\d{2}$`, unique. `ZNZ` = study participant, `PIL` = pilot volunteer (excluded from analysis). |
| `consentRecorded` | bool | Must be `true` before the camera can start (FR-017). |
| `consentRecordedAt` | ISO 8601 datetime | Set when `consentRecorded` becomes true. |
| `consentFormRef` | string | Reference number of the paper consent form. Never a name. |
| `patternSeed` | uint64 | Generated once at registration. Never changes (FR-006). |
| `withdrawn` | bool | When set to true, all of this participant's sessions and events are deleted (FR-026). |
| `createdAt` | ISO 8601 datetime | |

No name, phone number, village, or photo is stored, ever. Any key linking codes to people stays on
paper with the partner organization.

### Session

One run of the app within visit Session 1 or Session 2.

| Field | Type | Rules |
|---|---|---|
| `id` | UUID | |
| `participantCode` | string | Must reference an existing, non-withdrawn participant. |
| `visit` | enum | `session1` or `session2` (FR-019). A `session2` requires an earlier completed `session1`. |
| `facilitatorCode` | string | e.g. `F1`. Never a name. |
| `cameraSetup` | enum | `overheadRear` or `mirrorFront` (research R9). |
| `deviceModel` | string | e.g. `iPad (8th generation)`. |
| `osVersion` | string | |
| `appVersion` | string | |
| `startedAt` | ISO 8601 datetime | |
| `endedAt` | ISO 8601 datetime or null | |
| `outcome` | enum | `completed`, `aborted`, or `inProgress`. |
| `abortReason` | enum or null | `participantStopped`, `facilitatorStopped`, `faceGuard`, `deviceIssue`, `other`. |

### SessionEvent

Append-only and timestamped. The full schema is in
[contracts/session-event-log.schema.json](contracts/session-event-log.schema.json).

| Field | Type | Rules |
|---|---|---|
| `sessionId` | UUID | |
| `seq` | int | Increases monotonically within a session, starting at 0. |
| `t` | ISO 8601 datetime with milliseconds | |
| `type` | enum | See the schema. |
| `data` | object | Fields that depend on `type` (e.g. `step`, `view`, `reason`). Never contains image data. |

### MeasureResponse (paper → spreadsheet)

Collected on paper at the baseline and follow-up visits, then entered by the researcher. One row
per participant per visit. Columns are defined in [contracts/measures.md](contracts/measures.md).

## Runtime data (in memory only)

### HandFrame

The output of a `HandTracker` for one camera frame.

| Field | Type | Notes |
|---|---|---|
| `timestamp` | seconds (monotonic) | |
| `hands` | array of 0–2 `TrackedHand` | |

**TrackedHand**

| Field | Type | Notes |
|---|---|---|
| `chirality` | `left`, `right`, or `unknown` | From the tracker; fallback by position continuity (research R5). |
| `joints` | 21 × (x, y, confidence) | Image coordinates, smoothed with the One Euro filter. Low-confidence joints are interpolated from their neighbors. |
| `surface` | `palm`, `back`, or `edgeOn` | From the winding rule with hysteresis (research R5). |
| `scale` | float | Wrist to middle-finger knuckle distance. Sets finger widths and mark sizes. |

### GlowPattern

Generated from `patternSeed`. The same seed always produces the same pattern (FR-006).

| Field | Type | Notes |
|---|---|---|
| `seed` | uint64 | |
| `marks` | array of `GlowMark` | Default 5 caps + 24 streaks + 220 flecks + 9 patches per hand side (`look.json`), scaled down by adaptive quality. |

**GlowMark**

| Field | Type | Notes |
|---|---|---|
| `hand` | `left` or `right` | |
| `surface` | `palm` or `back` | Distinct patterns per side (FR-005). |
| `region` | enum | `fingertip`, `thumb`, `interdigital`, `dorsalFinger`, `backOfHand`, `palmEdge`, `palm`, `wrist`. |
| `anchor` | `Anchor` | See below. |
| `kind` | `cap`, `streak`, `fleck`, or `patch` | See research R7. A `cap` has exactly one per finger and thumb, per side. |
| `size` | float | Relative to the hand's `scale`. |
| `intensity` | 0…1 | |
| `hue` | 0…1 | Position within the glow palette in `look.json` (lime to mint green by default, from the references). |

**Anchor**: either `bone(jointA, jointB, t ∈ [0,1], s ∈ [-0.7, 0.7])` or
`triangle(j1, j2, j3, barycentric u, v, w)`.

- `s` is a sideways offset in units of the finger's estimated half-width. Limiting it to ±0.7
  keeps marks inside the finger.
- The triangles cover the palm and back of the hand, using the wrist, thumb base, and the four
  knuckle joints.

**Validation rules** (unit tested):
- The same seed gives an identical `marks` array.
- For each region, the left- and right-hand mark counts differ by at most 10% (FR-004).
- The region distribution matches the weights in research R7, within sampling tolerance.
- Rendered on a reference hand pose, glow covers 15–25% of the hand. Coverage by fifths, from
  the fingertips down, matches research R7 within ±10 percentage points.

### FadeState

A per-session multiplier for each `(hand, surface, region)`, from 1.0 (full glow) to 0.0 (gone).

- It drops during the quick-rinse demo and during the rehearsal steps, following the step-to-region
  map in research R7.
- It is never saved, so every session starts from the full pattern.

## State transitions: session flow

```text
idle
 └─▶ consentCheck ──(consent not recorded)──▶ blocked
 └─▶ deviceReady ──▶ positioning ──(hands detected)──▶ normalView
normalView ──(facilitator: next)──▶ uvIntro (spoken explanation, FR-008)
uvIntro ──▶ uvReveal ◀──(toggle)──▶ normalView2   (view switching, FR-007)
uvReveal ──(facilitator: next)──▶ quickRinseDemo ──▶ rehearsal[1..6] ──▶ realWashPrompt
realWashPrompt ──▶ debrief ──▶ ended(completed)

any state ──(participant or facilitator stop)──▶ ended(aborted)   (debrief N19 first if uvIntro was reached, FR-021)
any camera state ──(face detected)──▶ paused(faceGuard)
paused(faceGuard) ──(face gone)──▶ previous state
rehearsal[n] ──(fewer than 2 hands for more than 1 s)──▶ paused(step n)
paused(step n) ──(both hands back)──▶ rehearsal[n]
```

Every transition writes a `SessionEvent`. `idle` and `ended` are logged as `sessionStarted` /
`sessionEnded`, and `normalView2` as `viewSwitched`; every other state is logged as `stateEntered`. The full screen-by-screen contract, with the narration
clips for each state, is in [contracts/ui-flow.md](contracts/ui-flow.md).
