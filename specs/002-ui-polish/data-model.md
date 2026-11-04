# Data Model: UI Polish of the Session Flow

**Feature**: `002-ui-polish` | **Date**: 2026-11-04 | **Plan**: [plan.md](plan.md)

All entities are runtime UI state, held in memory only. Nothing is stored or exported, and the
001 session log is unchanged.

## Motion token

A named motion value shared by every screen ([contracts/motion-and-surfaces.md](contracts/motion-and-surfaces.md)).

| Field | Type | Rules |
|---|---|---|
| `name` | enum | `standard`, `quick`, `lamp`, `glowSpread`, `reducedFade` |
| `kind` | enum | `spring` (response, damping) or `timed` (duration, curve) |
| `response` / `duration` | seconds | `standard` 0.35, `quick` 0.2, `lamp` 0.8, `glowSpread` 1.5, `reducedFade` 0.2 |
| `damping` | 0…1 | 1.0 for every spring (no overshoot, FR-005) |
| `reduced` | token | The equivalent when Reduce Motion is on: always `reducedFade` (FR-017) |

## Surface style

| Field | Type | Rules |
|---|---|---|
| `role` | enum | `chrome` (facilitator strip, simulation badge) or `calm` (debrief, ended) |
| `translucent` | bool | `chrome` only; false when Reduce Transparency, Increase Contrast, or `QualityLevel` below `high` (FR-018, FR-021) |
| `edge` | bool | Bright top edge when translucent; contrasting border when solid |

## Lamp transition

The renderer's view-change state ([contracts/lamp-transition.md](contracts/lamp-transition.md)).

| Field | Type | Rules |
|---|---|---|
| `uvAmount` | 0…1 | 0 = camera image, 1 = full UV look; advanced every frame by the integrator (research D1) |
| `uvTarget` | 0 or 1 | Set by the flow; changing it mid-transition continues from the current `uvAmount` (FR-004) |
| `velocity` | per second | Carried across retargets, so reversals have no jump |
| `glowReveal` | 0…1 | One-time fingertip → wrist spread at the first switch-on of a session (FR-004a) |
| `spreadPlayed` | bool | Reset at session start; with Reduce Motion the spread is skipped |
| `badgeRequired` | bool | Published by the renderer: `uvTarget == 1 || uvAmount > 0` (FR-003). The UI also keeps the badge from uvIntro through normalView2 and until a calm surface is opaque |

**Transitions** (per entered state, [contracts/lamp-transition.md](contracts/lamp-transition.md) §1):
animated → 1 on `uvReveal` and on `quickRinseDemo` if off; animated → 0 on `normalView2` and
`realWashPrompt`; unchanged on `debrief`/`ended` (last frame held under the calm surface, then
reset); snapped to 0 elsewhere. Face guard blanks immediately, whatever `uvAmount` is (FR-020).

## Flow step

What the facilitator's step indicator shows (FR-012).

| `SessionState` | Step |
|---|---|
| `positioning` | 1 Position |
| `normalView` | 2 Look |
| `uvIntro` | 3 Lamp |
| `uvReveal`, `normalView2` | 4 Reveal |
| `quickRinseDemo` | 5 Quick rinse (built in 001 US3) |
| `rehearsal(1…6)`, `paused(.step)` | 6 Rehearsal, with six sub-ticks (001 US3) |
| `realWashPrompt` | 7 Real wash (001 US3) |
| `debrief` | 8 Debrief |
| `paused(.faceGuard)`, `paused(.facilitator)` | The step that was paused (from the state machine's `resumeState`), marked paused |

See research D9 and [contracts/motion-and-surfaces.md](contracts/motion-and-surfaces.md).

## Prompt visibility

| Prompt | Shown when | Fallback |
|---|---|---|
| Positioning arrow nudge | `NarrationPlayer.currentClip` becomes N01 or N02 | State entry + 0.5 s |
| Turn-hand prompt | `currentClip` becomes N06, not before the glow spread ends | Lamp switch + 14 s (unpaused time) |
| Eye / lamp buttons | `currentClip` becomes N07 | Lamp switch + 26 s (unpaused time) |
| Hands-found confirmation | Hands detected for 0.5 s on positioning | — |

Cues are latched in `AppModel` (research, changes 5). Exact timings follow [contracts/choreography.md](contracts/choreography.md) §5.

## Study settings (FR-025)

| Field | Type | Rules |
|---|---|---|
| `reduceMotion`, `reduceTransparency`, `increaseContrast` | bool | Expected false for study sessions |
| `textSize` | Dynamic Type category | Expected the default (`large`) |
| `osVersion` | string | Recorded |
| `matchesProfile` | bool | False → facilitator warning before start; recorded with the session |

## Hold-to-end

| Field | Type | Rules |
|---|---|---|
| `progress` | 0…1 | Fills over 1.0 s while held; at 1 → `facilitatorEnd()` |
| `released early` | — | Progress returns to 0 with `Motion.standard`; nothing happens (FR-015) |
