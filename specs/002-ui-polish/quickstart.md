# Quickstart & Validation Guide: UI Polish of the Session Flow

**Feature**: `002-ui-polish` | **Plan**: [plan.md](plan.md)

How to prove the polish works. Run on **every study iPad**, in the session room, with Airplane
Mode on, using the QA app (demo launcher) (constitution Gate 1). Screen recordings follow the
recording protocol below (Principle II).

## Prerequisites

- 001 MVP installed (QA build), physical setup A, dark cloth.
- The study accessibility profile set on the iPad (FR-025): Reduce Motion, Reduce Transparency,
  Increase Contrast off; default text size. Q8 and Q9 change these temporarily and restore them.
- **Recording protocol** (`docs/qa/recording-protocol.md`, research D18): only consenting
  volunteers who are not in the cohort, with consent recorded; a QA iPad with iCloud Photos off and
  Airplane Mode on; recordings moved to the Mac by cable; deleted from the iPad and the Mac after
  measuring, with the deletion logged; never on participant sessions.
- iPad screen recording on (Control Centre), and a Mac with Xcode for `tools/measure_transition.swift`.
- Accessibility toggles available: Settings → Accessibility → Motion (Reduce Motion), Display &
  Text Size (Reduce Transparency, Increase Contrast, Larger Text).

## Scenarios

| # | Scenario | How | Expected outcome | Proves |
|---|---|---|---|---|
| Q1 | **Lamp switch-on brightness** | Record the reveal; `swift tools/measure_transition.swift rec.mov` | Max consecutive-frame change in mean brightness ≤ 10% during every view change | SC-001, FR-001 |
| Q2 | **Skin before glow; badge before glow** | Step through Q1's recording frame by frame | Skin is violet before the first glow; badge fully visible in the first glow frame | FR-002, FR-003, SC-002 |
| Q3 | **Glow spread** | Same recording | Fingertips light first, wrist last, over ~1.5 s; final frame matches an all-at-once render | FR-004a |
| Q4 | **Reversal mid-change** | Tap eye, then lamp within 0.3 s, five times fast | Each change reverses from where it is; no jump, no stuck state | FR-004, edge cases |
| Q5 | **Lamp click** | Record with audio | Click starts within one frame of the visual change, only at switch-on, never over a clip start | FR-016 |
| Q6 | **Press feedback and Stop** | Record taps on every control; tap Stop mid-transition and again during the debrief (N19) | Feedback in the first frame after touch-down; Stop visible on every screen until the end and ends the session at once (aborted, participant stopped) | SC-003, FR-006, FR-007 |
| Q7 | **Prompts with narration** | Watch the reveal with audio | Turn-hand prompt appears with N06, eye/lamp with N07; hands-found confirmation on positioning | FR-009, FR-010 |
| Q8 | **Reduce Motion** | Turn on, walk the whole demo flow | Only fades, nothing loops, no glow spread | SC-005, FR-017 |
| Q9 | **Transparency, contrast, text size** | Turn each on in turn | Strip and badge solid with contrasting edge; facilitator text grows without overlapping the hands view | FR-018, FR-019 |
| Q10 | **Facilitator strip** | Facilitator runs 3 mock sessions; ask "which step?" at 5 moments | Zero accidental ends (hold-to-end); ≥ 4/5 correct step answers | SC-004, FR-012..015 |
| Q11 | **Performance** | QA app Device Check / replay harness during transitions on the oldest iPad | Render rate ≥ 001 targets throughout | SC-006, FR-021 |
| Q12 | **Face guard mid-transition** | Hold a printed face of a consenting team member into the frame during switch-on | Screen blanks on the same frame; on resume no click and no replayed spread | FR-020 |
| Q13 | **Spoken explanation gate** | (a) Remove N04 from a QA build and try to start; (b) make N04 fail at run time | (a) The session does not start and names the missing clip; (b) the lamp waits on the lamp screen until the facilitator taps Next | FR-004b |
| Q14 | **Study profile** | Turn Reduce Motion on, start a session; turn it off again | Facilitator warning before start; the settings and iPadOS version are recorded | FR-025 |
| Q15 | **Calm screens** | Record Next from the reveal to the debrief, and Stop from the reveal | No brightness jump (`measure_transition`); the badge is covered together with the glow, never before it; Stop remains on the debrief | FR-003, FR-024, FR-007 |

## Before the pilot

1. Q1–Q15 pass on every study iPad, offline, in the session room.
2. Partner staff review the hands-found confirmation, step indicator, glow spread, and lamp click
   (SC-008), together with 001's V13 content review.
3. The pilot (001 T104) asks each volunteer, with a pictorial scale or spoken answer, how the
   lamp switching on felt (calm / pleasant / startling), and records it in
   `docs/qa/pilot-report.md` (SC-007).
4. The app version with this polish is the one used for all `ZNZ` sessions (FR-023), on iPads set
   to the study profile (FR-025).
