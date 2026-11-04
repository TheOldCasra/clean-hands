# Implementation Plan: UI Polish of the Session Flow

**Branch**: `002-ui-polish` | **Date**: 2026-11-04 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/002-ui-polish/spec.md`

## Summary

Make the session flow feel calm, physical, and consistent, following the apple-design guidance
(response, interruptibility, critically damped springs, spatial consistency, materials,
multimodal feedback, reduced motion, typography).

- **The lamp moment (US1)**: the normal → UV switch becomes a 0.8 s renderer-driven transition
  (`uvAmount` 0→1): background darkens and skin turns violet first, then the glow spreads from the
  fingertips toward the wrist over 1.5 s the first time. It reverses from wherever it is.
- **One motion language (US2)**: shared motion tokens, a pressable button style, prompts that
  arrive with the narration clip that introduces them, a hands-found confirmation, and no loops.
- **Facilitator strip (US3)**: a translucent, legible strip with a shapes-only step indicator,
  44 pt targets, and hold-to-end.
- **Lamp click (US4)**: a soft synthesized click on the same frame as every switch-on.
- **Accessibility**: Reduce Motion, Reduce Transparency, Increase Contrast, and Dynamic Type
  (facilitator text) honoured everywhere.

Design detail lives in three contracts: [lamp-transition.md](contracts/lamp-transition.md),
[motion-and-surfaces.md](contracts/motion-and-surfaces.md), and
[choreography.md](contracts/choreography.md).

## Technical Context

**Language/Version**: Swift 6, Metal Shading Language (unchanged from 001)

**Primary Dependencies**: Apple frameworks only: SwiftUI (springs, materials, accessibility
environment), Metal (lamp transition and glow spread in the existing passes), AVFAudio (lamp
click). No third-party packages.

**Storage**: None new. One bundled sound asset (`LampClick.caf`, synthesized by a script).

**Testing**:
- Unit tests (Swift Testing) for the lamp transition integrator (continuity, retargeting without
  a jump, channel ordering), glow reveal order (monotonic, final state equals the 001 pattern),
  state → step mapping, prompt cue scheduling, the lamp-click rule, and reduced-motion token
  selection. Hold-to-end is a system long-press; it is checked manually (quickstart Q10).
- GPU render tests (extending 001's `RendererTests`) at fixed `uvAmount` values: brightness
  monotonic and no glow before the glow gate.
- `tools/measure_transition.swift`: per-frame mean brightness from a screen recording (SC-001).
- Manual slow-motion review with the choreography checklist (SC-002, SC-003, SC-005).

**Target Platform**: iPadOS 17.0+, iPad only (unchanged).

**Project Type**: Mobile app (existing `ios/` project).

**Performance Goals**: 001 targets hold during transitions: 60 fps on A12+, ≥ 30 fps on A10
(SC-006). Transition math is a handful of uniforms per frame; materials only on small chrome and
solid at reduced quality.

**Constraints**:
- Icon-first participant UI; no new participant text (Principle VII).
- Badge visible before the first glow (Principle I).
- Stop works during every transition; face-guard blanking is immediate and exempt (Principles V,
  VII).
- Polished flow frozen before the first `ZNZ` session (Principle III).

**Scale/Scope**: 7 participant states polished now, 1 facilitator strip, 1 idle screen; shared
components adopted later by the remaining 001 screens.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design.*

| Principle | Status | How the plan complies |
|---|---|---|
| I. Truthful Simulation | ✅ | Badge appears before any glow and is covered only together with the glow (FR-003); it is a solid chip on every iPad (FR-026); the first reveal never happens without the spoken explanation (FR-004b); the glow spread changes only timing, not the pattern or its meaning |
| II. Privacy by Design | ✅ | No new data; the app stores no frames. Validation needs screen recordings of the camera view; they follow a recording protocol (consenting non-cohort volunteers, QA iPad with iCloud Photos off and Airplane Mode on, cable transfer, deletion logged; a printed face for the face-guard check) and never happen on participant sessions |
| III. Research Validity First | ✅ | Polish lands before the pilot and is frozen with the app version before the first `ZNZ` session (FR-023); all study iPads use one accessibility profile, checked and recorded at session start (FR-025); the badge looks the same everywhere (FR-026) |
| IV. Pretrained Models First | ✅ | Not affected |
| V. Motivate, Don't Frighten | ✅ | The cut to black is replaced by a calm lamp transition; no overshoot; Stop is visible and working on every screen until the session ends, debrief included (FR-007); the pilot asks whether the lamp felt calm (SC-007) |
| VI. MVP Simplicity | ✅ | Native springs and materials only; every addition is justified in Complexity Tracking below |
| VII. Culturally Grounded & Accessible | ✅ | No new text; every new or changed participant-visible element and the lamp click go to partner review (SC-008); system accessibility settings honoured |

**Post-design re-check (after Phase 1)**: ✅ all principles still pass. The contracts keep the
face guard exempt from transitions, keep every participant element icon-only, and add no data.

## Project Structure

### Documentation (this feature)

```text
specs/002-ui-polish/
├── spec.md
├── plan.md                         # This file
├── research.md                     # Phase 0: decisions D1–D18
├── data-model.md                   # Phase 1: UI state entities
├── quickstart.md                   # Phase 1: validation scenarios Q1–Q15
├── contracts/
│   ├── lamp-transition.md          # Renderer: uvAmount, glow spread, badge signal, click sync
│   ├── motion-and-surfaces.md      # Tokens, PressableStyle, GlassSurface, StepIndicator, HoldToEndButton
│   └── choreography.md             # State-by-state enter/exit, reveal timeline, interruptions
├── checklists/requirements.md
└── tasks.md                        # Phase 2 (/speckit-tasks)
```

### Source Code (repository root)

```text
ios/CleanHands/
├── Design/                 # NEW: Motion.swift (tokens), PressableStyle.swift,
│                           #      GlassSurface.swift, PromptTransition.swift
├── Rendering/              # LampTransition.swift (NEW), Renderer.swift, Shaders.metal (uvAmount, glowReveal)
├── Audio/                  # NarrationPlayer.swift (currentClip), LampClick.swift (NEW)
├── Flow/                   # ParticipantRootView.swift, Screens/*, PromptSchedule.swift (NEW),
│                           # Components/HandsFoundConfirmation.swift (NEW)
├── Glow/                   # Anchoring.swift (revealOrder)
├── Facilitator/            # ControlStrip.swift, StepIndicator.swift (NEW), HoldToEndButton.swift (NEW)
├── App/                    # AppModel.swift (lamp target, prompt timing), StudySettings.swift (NEW)
└── Resources/              # LampClick.caf (NEW, generated)

ios/CleanHandsTests/
├── Rendering/              # LampTransitionTests.swift, GlowRevealTests.swift (NEW)
├── Design/                 # MotionTokenTests.swift (NEW)
└── Flow/                   # StepMappingTests.swift, PromptScheduleTests.swift (NEW)
                            # (Design/ also holds LampClickTests.swift; hold-to-end is checked manually, quickstart Q10)

tools/
├── make_lamp_click.py      # NEW: synthesizes LampClick (no third-party audio)
└── measure_transition.swift # NEW: per-frame brightness from a screen recording (SC-001)
```

**Structure Decision**: extend the existing `ios/` app. A new `Design/` group holds the shared
motion and surface vocabulary that both 002 and the remaining 001 screens use (FR-022).

## Complexity Tracking

| Addition | Why Needed | Simpler Alternative Rejected Because |
|---|---|---|
| Renderer-side transition integrator (`LampTransition`) | The lamp switch happens in the Metal pass; SwiftUI animations cannot drive shader uniforms frame-accurately, and FR-004 needs retargeting from the current value | A SwiftUI cross-fade of two views would double GPU work on A10 and cannot order skin-before-glow |
| Bundled lamp click | Clarified requirement (US4) for causality between sound and sight | Text-to-speech or a system sound cannot be timed to a frame or reviewed as an asset |
| `tools/measure_transition.swift` | SC-001 needs a repeatable brightness measure | Eyeballing slow motion cannot prove "≤ 10% per frame" |
| Glow spread (`revealOrder`, `glowReveal`, once-per-session rule) | Clarified requirement FR-004a | A screen-axis wipe changes order with hand pose and looks like a scanner |
| Badge interlock (`badgeOpaque` → `glowInterlock`) | Makes "badge before glow" (Principle I, FR-003) true by construction, including after a face-guard resume | Timing alone can be broken by a dropped frame or a resume; the cost is one bool and one multiplier |
| `PromptSchedule` (latched clip cues, unpaused-time fallbacks) and `NarrationPlayer.deferStarts` | FR-009 (prompts with their clip), FR-016 (no clip over the click), FR-004b (N04 gate); must survive pauses and missing clips | View-local timers lose cues on pause and cannot be unit tested |
| Calm-screen cross-fade over the held last frame | FR-024 (no brightness jump when leaving the camera view) | Cutting to the calm colour is the abrupt jump the audit found; fading the camera to black first is two steps |
| `GlassSurface` fallback chain and `qualityLevel` environment value | FR-018 (accessibility), FR-021 (frame rate on A10) | Always-solid chrome loses legibility over the moving image; always-glass costs GPU on A10 |
| `tools/make_lamp_click.py` + bundled `LampClick.caf` | US4/FR-016; a reproducible, reviewable asset with no third-party audio | Recording a real switch needs equipment and licensing; a system sound cannot be frame-timed |
| Accessibility profile check (`StudySettings`) | FR-025 (identical experience, Principle III) | A paper checklist alone cannot catch a setting changed between sessions |

## Phase Status

- [x] Phase 0: research.md (decisions from the three contracts)
- [x] Phase 1: data-model.md, contracts/ (3), quickstart.md; Constitution Check re-passed
- [x] Phase 2: `/speckit-tasks` (tasks.md, T001–T048)
