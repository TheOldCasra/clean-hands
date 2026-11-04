---
description: "Task list for UI polish of the session flow"
---

# Tasks: UI Polish of the Session Flow

**Input**: Design documents from `/specs/002-ui-polish/`

**Prerequisites**: plan.md, spec.md, research.md (D1–D18), data-model.md, contracts/
(lamp-transition, motion-and-surfaces, choreography), quickstart.md (Q1–Q15),
`.specify/memory/constitution.md` (v2.0.0). Builds on 001 (T001–T053 done).

**Tests**: Included. plan.md (Testing) asks for unit tests of the lamp integrator and its
channels, glow reveal order, prompt cues and the spoken-explanation gate, step mapping, the
lamp-click rule, and reduced-motion token selection, plus GPU render checks. Write each test task
first and confirm it fails.

**Organization**: by user story: US1 lamp switch (P1), US2 motion language (P2), US3 facilitator
strip (P3), US4 lamp click (P3).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an unfinished task)
- Paths are relative to the repository root (`clean-hands/`)
- Any task that adds a file ends by running `xcodegen generate` in `ios/` (the project lists
  files explicitly)

---

## Phase 1: Setup

- [X] T001 Create the groups `ios/CleanHands/Design/`, `ios/CleanHandsTests/Design/`, and `ios/CleanHandsTests/Rendering/`, then run `xcodegen generate` in `ios/` so `ios/CleanHands.xcodeproj` picks them up
- [X] T002 [P] After T001, write `tools/make_lamp_click.py` (standard library only, fixed seed): synthesize one soft click made of two transients 30 ms apart (second 8 dB quieter), 110 ms, peak −18 dBFS, no speech or third-party samples; convert with `afconvert -f caff -d LEI16@48000 -c 1` to `ios/CleanHands/Resources/LampClick.caf`; commit the asset and regenerate the project (research D5, lamp-transition §7)
- [X] T003 [P] Write `tools/measure_transition.swift` (run with `swift`): read a screen recording with AVFoundation, compute per-frame mean luma (0–255), print the largest consecutive-frame step with its timestamps, and exit non-zero if any step exceeds 25 (SC-001, lamp-transition L7)

---

## Phase 2: Foundational (blocking)

**Purpose**: the shared motion and surface vocabulary, the narration timing, the prompt schedule,
and the study settings that every story uses (FR-005, FR-022, FR-025).

- [X] T004 [P] Unit test the motion tokens in `ios/CleanHandsTests/Design/MotionTokenTests.swift`: every spring has damping 1.0 (no overshoot, FR-005); `Motion.animation(_:reduceMotion: true)` returns the reduced equivalent for each SwiftUI token; `RendererTiming.lamp` is 0.8 s with reduced 0.4 s, and `glowSpread` is 1.5 s with reduced 0 s
- [X] T005 Implement `ios/CleanHands/Design/Motion.swift`: `Motion.standard` (spring 0.35/1.0), `Motion.quick` (0.2/1.0), `Motion.reducedFade` (easeInOut 0.2 s), `Motion.Token`, `Motion.animation(_:reduceMotion:)`, and the renderer timings `Motion.lamp` and `Motion.glowSpread` as `RendererTiming` (seconds, reduced seconds); no literal durations outside this file except the hold-to-end fill (motion-and-surfaces §1)
- [X] T006 [P] Implement `PressableStyle` in `ios/CleanHands/Design/PressableStyle.swift`: a `ButtonStyle` whose highlight appears unanimated on touch-down, scale 0.96 with `Motion.quick`, no scale with Reduce Motion, configurable shape, highlight, and minimum hit size (motion-and-surfaces §2.1, research D8)
- [X] T007 [P] Implement `GlassSurface` in `ios/CleanHands/Design/GlassSurface.swift`: `glassSurface(_:prominence:)` with `GlassProminence`, dark `.thinMaterial` + black 0.3 tint + 1 pt top highlight; instant solid fallback in the order Increase Contrast → Reduce Transparency → `qualityLevel` `.medium`/`.low`; add `EnvironmentValues.qualityLevel`. Used by the facilitator strip only; the simulation badge is always solid (research D10, D17, FR-018, FR-021, FR-026)
- [X] T008 [P] Implement `promptTransition` in `ios/CleanHands/Design/PromptTransition.swift`: opacity + scale 0.92 → 1 in place, exact reverse on exit, opacity only with Reduce Motion (research D6, FR-008)
- [X] T009 Extend `ios/CleanHands/Audio/NarrationPlayer.swift`: observable `currentClip` and `currentClipStartedAt` (`CACurrentMediaTime`), both set at a clip's actual start and cleared at its end; `deferStarts(until:)` holds any clip start (a new `play` or the next in a queue) until that time, counts a deferred clip as `isPlaying`, is cancelled by `stop()`, and fires `onClipPlayed` at the actual start; `missingClips()` lists any of N01–N21 not in the bundle; keep the asynchronous hop for missing clips so callbacks never run inside a state-machine mutation (lamp-transition §7, research D16)
- [X] T010 [P] Unit test `PromptSchedule` in `ios/CleanHandsTests/Flow/PromptScheduleTests.swift` with a fake clock: the lamp may switch on only after N04 has ended normally and uvIntro has lasted ≥ 1.0 s, or after the facilitator's Next when N04 is missing or failed, never on a timer (FR-004b); turn-hand appears at the N06 start but not before the spread ends (G2); eye/lamp at the N07 start; fallbacks at lamp switch + 14 s and + 26 s in unpaused time; a cue latched before a pause survives it; after a resume, prompts not yet shown enter at once with no entrance replay; a late cue replays only the hint (choreography §5)
- [X] T011 Implement `PromptSchedule` in `ios/CleanHands/Flow/PromptSchedule.swift`: a pure struct (clip starts and ends, unpaused time, gates, facilitator Next → whether the lamp may switch on, visible prompts, pending hints)
- [X] T012 [P] Implement `StudySettings` in `ios/CleanHands/App/StudySettings.swift`: read Reduce Motion, Reduce Transparency, Increase Contrast, the text size category, and the iPadOS version; `matchesProfile` is true only for the study profile (all off, default text size); expose a snapshot that 001's `deviceCheck` event will record (001 T067, T072) (FR-025, research D17)
- [X] T013 In `ios/CleanHands/App/AppModel.swift` and `ios/CleanHands/Flow/SessionStateMachine.swift`: expose the state machine's `resumeState` (read-only); keep one `PromptSchedule` fed from `NarrationPlayer.currentClip`; hold a `StudySettings` snapshot taken at session start. In `ios/CleanHands/Flow/ParticipantRootView.swift`: forward `accessibilityReduceMotion` with `.onChange(of:initial: true)` to the model, which passes it to the renderer (`Renderer.reduceMotion`); set `\.qualityLevel` from `AppModel.quality`. Never call the state machine synchronously from `entered(_:from:)` or from callbacks it triggers

**Checkpoint**: shared components compile and their tests pass; no screen uses them yet.

---

## Phase 3: User Story 1 - The lamp switches on (Priority: P1) 🎯 MVP

**Goal**: the normal ⇄ UV change is a calm, interruptible 0.8 s transition; skin before glow; the
glow spreads from the fingertips the first time; the badge always leads the glow; the first reveal
always follows the spoken explanation; leaving the camera view never jumps in brightness.

**Independent Test**: quickstart Q1–Q4, Q12, Q13, and Q15 with the QA app.

### Tests for User Story 1 ⚠️

- [X] T014 [P] [US1] Unit test the lamp in `ios/CleanHandsTests/Rendering/LampTransitionTests.swift`: `LampTransition.channels(a, reduceMotion:)` for both modes (dark, skin, gate); L1 (`uvAmount ≥ 0.99` at 0.80 ± 0.02 s at dt 1/60 and 1/30; Reduce Motion done at 0.60 s); L2 (400 random runs, ≤ 10 reversals, 5 % tripled dt, 24–60 fps: Δdark ≤ 0.09, Δskin ≤ 0.11, white-scene mean Δ ≤ 0.095 per frame); L3 (`gate > 0` ⇒ skin and dark at 1; on switch-off the last glow frame precedes the first `skin < 1` frame); L4 (retarget every frame: `|ΔuvAmount| ≤ dt/0.7 + 0.002`; a reversal spans ≥ 3 frames); `badgeRequired` rises in the `setView` call and falls when `uvAmount` snaps to 0; `frozen` stops integration and a resume makes no 0 → 1 edge; `resetLamp()` zeroes the state (lamp-transition §1–§6, §10)
- [X] T015 [P] [US1] Unit test the glow spread in `ios/CleanHandsTests/Rendering/GlowRevealTests.swift` on the pure functions: `revealOrder` rises tip → DIP → PIP → MCP → wrist → forearm within 0…1; the reveal factor is exactly 1 for every mark at `glowReveal = 1` (so the final frame equals the 001 pattern); the spread plays once per session; Reduce Motion skips it
- [X] T016 [P] [US1] Extend `ios/CleanHandsTests/Glow/RendererTests.swift`: first, with the current pipeline, save the UV render of seed 42 as `ios/CleanHandsTests/Resources/uv-reference-seed42.png` and commit it; then add L6: render at fixed `uvAmount` 0, 0.25, 0.5, 0.75, 0.8, 1 with `renderOffscreen(pixelBuffer:frame:uvAmount:)`: mean luma non-increasing over 0…0.8 and rising by at most 0.05 of full range from 0.8 to 1 (the glow adds light); no glow pixel at ≤ 0.80; `uvAmount` 1 matches the reference within 1 LSB; `uvAmount` 0 equals the camera image exactly

### Implementation for User Story 1

- [X] T017 [US1] Implement `LampTransition` in `ios/CleanHands/Rendering/LampTransition.swift`: fields `uvTarget`, `uvLinear`, `uvAmount`, `velocity`, `glowReveal`, `glowInterlock`, `badgeRequired`, `frozen`; the rate-limited ramp (Tr 0.7 s) with closed-form critically damped follower (response 0.2 s), snap, and start kick (±1/Tr); `dt` capped at 1/30 s; the pure `channels(a, reduceMotion:)` (standard: dark `h(a/0.78)`, skin `smoothstep(0.05, 0.78, a)`, gate `smoothstep(0.80, 1, a)`; Reduce Motion: dark = skin = `clamp(a/0.65)`, gate `clamp((a − 0.67)/0.33)`, Tr 0.6 s, no follower); `resetLamp()` (lamp-transition §1–§4)
- [X] T018 [US1] Add `revealOrder` for each mark, computed from its `Anchor` by joint-chain distance (tip 0, DIP 1/3, PIP 2/3, MCP 1, wrist 2, forearm 2 + `pattern.wristExtent`, normalized), stored with the prepared marks in `ios/CleanHands/Rendering/Renderer.swift` and recomputed when the config changes; add the reveal factor `smoothstep((glowReveal·1.35 − revealOrder)/0.35)`, forced to 1 at `glowReveal = 1`, in `ios/CleanHands/Glow/Anchoring.swift` (lamp-transition §5)
- [X] T019 [US1] In `ios/CleanHands/Rendering/Shaders.metal`, replace the final pass's normal/UV switch with a mix: `flags.x` = `uvAmount` (for the `== 0` camera fast path), `texel.zw` = `dark` and `skin` from `channels(…)`, `bloom.w` = `blankAmount` (black first); `outside = mix(cam, background, dark)`, `inside = mix(cam, ramp, skin)`, nail tint × `skin`; no new uniform bytes; the shader never needs the Reduce Motion flag (lamp-transition §3, §8)
- [X] T020 [US1] Update `ios/CleanHands/Rendering/Renderer.swift`: `setView(_:animated:) -> Bool` (true when an animated 0 → 1 edge starts) with `mode` read-only; `reduceMotion` and `frozen` inputs; integrate `LampTransition` every frame before the drawable/camera guard, so the lamp settles even without new frames; multiply each mark instance by gate × reveal factor × `glowInterlock` on the CPU; publish `badgeRequired`, `onLampSettled`, and `onSpreadEnded`; accept `badgeOpaque`; redefine `glowVisible` as any instance intensity > 0.01; `blankAmount` = 1 on the face-guard frame, falling over `Motion.lamp` after; add `renderOffscreen(pixelBuffer:frame:uvAmount: Float = 1)` that forces reveal and interlock to 1 locally without touching live state, and move `ios/CleanHandsTests/Glow/RendererTests.swift` and `ios/CleanHands/Debug/ReplayHarness.swift` to it (remove their `mode` assignments); in QA builds assert `!glowVisible || badgeOpaque` every frame; switch-frame GPU cost ≤ +0.3 ms (L11)
- [X] T021 [US1] Drive the lamp from `ios/CleanHands/App/AppModel.swift`, following the per-state table in lamp-transition §1: animated → 1 on `.uvReveal` (and `.quickRinseDemo` if off), animated → 0 on `.normalView2` (and `.realWashPrompt`), unchanged on `.debrief`/`.ended` (T024), snapped elsewhere; `resetLamp()` on `.idle` and when a pattern is assigned; leave uvIntro only when `PromptSchedule` allows it (N04 ended normally and ≥ 1.0 s, or the facilitator's Next; FR-004b), using a per-visit token so a timer from an earlier visit can never fire; after the switch, `narration.deferStarts(until: click + 0.8 s)` and start N05–N07 at the later of that time and `onLampSettled`, with a 1.0 s timeout; pauses and face guard set `renderer.frozen`; resuming replays neither the click, the spread, nor any prompt entrance
- [X] T022 [US1] Refuse to start a session while `NarrationPlayer.missingClips()` is not empty, naming the missing clips to the facilitator, in `ios/CleanHands/Debug/DemoLauncher.swift` and `ios/CleanHands/App/AppModel.swift`; add the same check to 001's Device Check task (001 T072) in `specs/001-uv-germ-visualization/tasks.md` (FR-004b, research D16)
- [X] T023 [US1] Badge, in `ios/CleanHands/Flow/ParticipantRootView.swift` and `ios/CleanHands/Flow/Components/SimulationBadge.swift`: show it from uvIntro entry through normalView2, whenever `badgeRequired`, and while a calm surface fades in after a camera state (until the surface is opaque); hide it with no animation on face-guard frames; restyle it as a solid chip (dark fill, white 1 pt border), identical on every iPad and quality level, at its fixed top-leading anchor, opacity with `Motion.quick`; drive its opacity from view-local `@State` changed in `.onChange` with `withAnimation(Motion.quick, completionCriteria: .removed)`, set `model.badgeOpaque = true` in the completion and false synchronously when hiding; after a pause or face guard, restore it without an entrance and set `badgeOpaque` at once (research D4, D11, FR-003, FR-026)
- [X] T024 [US1] Calm-surface cross-fade on debrief, end, and Stop (research D15, FR-024), in `ios/CleanHands/App/AppModel.swift`, `ios/CleanHands/Flow/ParticipantRootView.swift`, and `ios/CleanHands/Rendering/Renderer.swift`: on entry the state changes at once; capture stops and `frames.clear()` stops presenting, so the view keeps its last image; `MetalCameraView` stays mounted (view-owned flag) until the solid calm surface, fading in over 0.8 s with the smoothstep curve (the same for Stop), is opaque; the badge stays under it (T023) and Stop stays above it (T026); `blank` is not set on abort unless the abort came from the face guard; the lamp is reset only once the surface is opaque; no delayed `stopCamera` (no sleeping task that could stop the next session's camera)
- [ ] T025 [US1] Verify on the QA build that a face entering mid-switch blanks the next frame and that resume plays no click and no spread (lamp-transition L10, quickstart Q12, with a printed face per the recording protocol); record the result in `docs/qa/002-validation-log.md`

**Checkpoint**: the reveal is a calm, reversible lamp switch with a fingertip-first glow; the badge
leads every glow and is never removed before it; the reveal never starts unexplained.

---

## Phase 4: User Story 2 - One calm motion language across the flow (Priority: P2)

**Goal**: every participant control responds on touch-down, prompts arrive with their narration
and leave the way they came, hands-found is confirmed, Stop is always there, and nothing loops.

**Independent Test**: quickstart Q6–Q8: walk the demo flow on a screen recording with Reduce
Motion off and on. (Prompt timing is unit tested in T010.)

### Implementation for User Story 2

- [X] T026 [P] [US2] Exit button (door symbol, top corner, `PressableStyle`) replaces the red Stop in `ios/CleanHands/Flow/ParticipantRootView.swift`: above every participant layer, calm surfaces included, on every screen from session start until `ended`, enabled through every transition (FR-007, owner review 2026-11-04)
- [ ] T027 [US2] Rework `ios/CleanHands/Flow/Screens/UVRevealView.swift`: eye/lamp buttons with `PressableStyle(shape: Circle(), minHitSize: 88)`, the selected one white-filled with a black icon (selection fill with `Motion.quick`), shown from the N07 cue (`PromptSchedule`); the turn-hand prompt is a hand glyph that turns over 180° about the vertical axis once per N06 cue (mirrored cross-fade with Reduce Motion), replacing the circular arrows (research D13)
- [ ] T028 [US2] Rework `ios/CleanHands/Flow/Screens/PositioningView.swift`: the camera image fades up from black on entry (choreography C6); the arrow sits above the hand outline and nudges down onto it once per N01/N02 cue latched in `PromptSchedule`, both entering with `promptTransition` (research D14)
- [ ] T029 [P] [US2] Implement `HandsFoundConfirmation` in `ios/CleanHands/Flow/Components/HandsFoundConfirmation.swift`: the outline cross-fades to a filled glyph (white 0.95, never glow green or lamp violet), filled by 0.2 s; it only animates and never controls the flow (FR-010, choreography §4)
- [ ] T030 [US2] In `ios/CleanHands/App/AppModel.swift`, own the positioning timing: after hands are seen continuously for 0.5 s (tracking timestamps), latch `confirmingSince` (observable, drives `HandsFoundConfirmation`) and advance to normalView 0.5 s later, even if the hands leave meanwhile
- [ ] T031 [US2] In `ios/CleanHands/Flow/ParticipantRootView.swift`, give prompt and icon layers `promptTransition` with `Motion.animation(.standard, reduceMotion:)`, keyed by overlay identity (uvReveal and normalView2 share one identity, so eye/lamp taps do not re-enter the buttons); insert the face-guard layer with `.transaction { $0.animation = nil }`; leave calm surfaces to T024; use no entrance animation when the previous state was paused; remove the repeat-forever no-hands pulse (it now uses the PositioningView nudge per N02 cue, or opacity emphasis with Reduce Motion); replace the deviceReady spinner with a static camera glyph after 1 s (FR-011, FR-017, FR-020)
- [ ] T032 [US2] After T023, rework `ios/CleanHands/Flow/Screens/UVIntroView.swift`: the lamp icon enters in place with `promptTransition` and leaves on the lamp switch frame; remove its own badge (the root view's badge from T023 covers uvIntro)
- [ ] T033 [US2] After T024, add the debrief and ended icons to the calm screens in `ios/CleanHands/Flow/ParticipantRootView.swift`: icons enter with `promptTransition` only once the surface is opaque, swap in place between debrief and ended, and Stop stays visible until `ended` (choreography §7)

**Checkpoint**: the whole participant flow moves with one vocabulary; Reduce Motion shows only fades.

---

## Phase 5: User Story 3 - Facilitator controls (Priority: P3) — removed

**Removed 2026-11-04 by the owner** (spec Clarifications): no facilitator strip, no pause, no
step indicator, no hold-to-end. T034–T037 are dropped; T038's typography applies to the new start
screen.

**Goal**: a legible, discreet strip that shows where the session is, with 44 pt targets and
hold-to-end.

**Independent Test**: quickstart Q9–Q10: a facilitator runs 3 mock sessions using only the strip.

### Tests for User Story 3 ⚠️

- [ ] T034 [P] [US3] Unit test `FlowStep` mapping in `ios/CleanHandsTests/Flow/StepMappingTests.swift` against motion-and-surfaces §2.4: idle, consentCheck, and blocked hide the indicator; deviceReady and positioning are step 1; each later state maps to one of the 8 steps (rehearsal with sub-tick n); paused states show the step from `resumeState`; ended shows no current step with the reached steps kept

### Implementation for User Story 3

- [ ] T035 [US3] Implement `FlowStep` and its mapping, and the `StepIndicator` view (8 steps, current step as a capsule with six rehearsal sub-ticks, advances with `Motion.standard`, cross-fade with Reduce Motion, shapes only), in `ios/CleanHands/Facilitator/StepIndicator.swift` (motion-and-surfaces §2.4)
- [ ] T036 [P] [US3] Implement `HoldToEndButton` in `ios/CleanHands/Facilitator/HoldToEndButton.swift`: one-finger hold for `holdDuration` = 1.0 s with a linear white ring (36 pt, 3 pt stroke, from 12 o'clock); early release or > 10 pt movement returns the ring with `Motion.standard`; fires `onEnd` once on completion; 44 × 44 pt target; no red (motion-and-surfaces §2.5, FR-015)
- [ ] T037 [US3] Rebuild `ios/CleanHands/Facilitator/ControlStrip.swift` on `glassSurface(Capsule(), prominence: .bar)`: order Back · StepIndicator · Next — Pause · Replay — End (hold); 44 × 44 pt `@ScaledMetric` buttons with `PressableStyle`; Dynamic Type capped so the strip never reaches the hands view; wire `StepIndicator` and `HoldToEndButton` in `ios/CleanHands/Flow/ParticipantRootView.swift` (FR-012..FR-014, FR-019)
- [ ] T038 [US3] Apply the typography rules (system text styles, no manual tracking, weight for hierarchy) to the idle screen in `ios/CleanHands/Flow/ParticipantRootView.swift` (`IdleView`), and show the `StudySettings` warning there when the profile does not match (motion-and-surfaces §4, FR-025)

**Checkpoint**: the facilitator can tell the step at a glance and cannot end a session by accident.

---

## Phase 6: User Story 4 - The lamp sounds like a lamp (Priority: P3)

**Goal**: a soft click on the same frame as every switch-on.

**Independent Test**: quickstart Q5: a recording with audio.

### Tests for User Story 4 ⚠️

- [ ] T039 [P] [US4] Unit test the click rule in `ios/CleanHandsTests/Design/LampClickTests.swift`: `LampClick.shouldPlay(lastClipStart:lastClick:now:)` (all `CACurrentMediaTime`) is false within 0.25 s after a clip start and within 0.2 s after the previous click, and true otherwise; switch-off and resume produce no click because `setView` returns false for them (covered in T014) (research D5)

### Implementation for User Story 4

- [ ] T040 [US4] Implement `LampClick` in `ios/CleanHands/Audio/LampClick.swift`: preload `LampClick.caf` into a prepared `AVAudioPlayer` on the narration's audio session at launch and after each play; `shouldPlay(lastClipStart:lastClick:now:)`
- [ ] T041 [US4] In `ios/CleanHands/App/AppModel.swift`, play `LampClick` in the same turn as every `setView` call that returns true, never delayed, when `shouldPlay` allows; the ≥ 0.8 s gap before the next clip is owned by T021's `deferStarts` (FR-016)

**Checkpoint**: sound and sight are one event at every switch-on.

---

## Phase 7: Polish & Cross-Cutting Concerns

- [ ] T042 Run the full unit and GPU test suite and the Release/QA builds; confirm Release still contains no debug-tool symbols (001 T099)
- [ ] T043 Write the recording protocol in `docs/qa/recording-protocol.md`: consenting non-cohort volunteers with recorded consent; QA iPad with iCloud Photos off and Airplane Mode on; cable transfer; deletion from iPad and Mac after measuring, with a deletion log; a printed face of a consenting team member for the face-guard check; never on participant sessions (research D18, Principle II)
- [ ] T044 Following T043, run quickstart Q1–Q15 on every study iPad, offline, in the session room, including lamp-transition L7–L11, and record results in `docs/qa/002-validation-log.md` (Gate 1)
- [ ] T045 [P] Prepare the partner review package in `docs/qa/002-partner-review.md` for every new or changed participant-visible element: the lamp switch-on look, the glow spread, the solid simulation badge and its new position, the hands-found confirmation, the positioning arrow nudge, the turn-hand glyph, the static camera glyph, the step indicator, and the lamp click; state that 001 T103 reviews the frozen build (SC-008)
- [ ] T046 [P] Add an adoption note to `specs/001-uv-germ-visualization/tasks.md` for the remaining US2/US3 screens (registration, consent, export, quick rinse, rehearsal, real wash, debrief), pointing them to motion-and-surfaces §7 and to the lamp's per-state table (FR-022)
- [ ] T047 [P] Add the SC-007 question (how the lamp switching on felt: calm / pleasant / startling, pictorial or spoken) to 001's pilot task (001 T104) in `specs/001-uv-germ-visualization/tasks.md`, and a results section for it in `docs/qa/pilot-report.md`
- [ ] T048 Record the frozen app version, and confirm the study accessibility profile and iPadOS version on every study iPad, in `docs/qa/002-validation-log.md`; add both to the 001 approvals checklist item (001 T106) in `specs/001-uv-germ-visualization/tasks.md` (FR-023, FR-025)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (1)** → **Foundational (2)** → user stories.
- **US1** depends on Foundational (including `PromptSchedule` T010–T011 and `deferStarts` T009).
- **US2** depends on Foundational; T032 needs T023, T033 needs T024, and the reveal prompts in T027
  read US1's spread-ended and settled signals (T020).
- **US3** depends on Foundational only.
- **US4** depends on US1 (T020 `setView` returning true, T021 `deferStarts`).
- **Polish**: T044 needs T043 and all stories; T045–T047 can start any time.

```text
Setup → Foundational ─┬─▶ US1 (P1) ─┬─▶ US4 (P3) ─┐
                      │             └─▶ US2 (T027, T032, T033)
                      ├─▶ US2 (P2) ─────────────────┼─▶ Polish
                      └─▶ US3 (P3) ─────────────────┘
```

### Shared files (run in order)

`AppModel.swift` (T013, T021, T022, T024, T030, T041), `ParticipantRootView.swift` (T013, T023,
T024, T026, T031, T033, T037, T038), `Renderer.swift` (T018, T020, T024), `Shaders.metal` (T019),
`LampTransition.swift` (T017), `NarrationPlayer.swift` (T009).

### Parallel Opportunities

- Setup: T002, T003 (after T001).
- Foundational: T004, T006, T007, T008, T010, T012 together (T004 compiles after T005; T010 after T011's type exists).
- US1 tests T014–T016 together.
- US2: T026, T029 together; US3: T034, T036 together; US3 can run alongside US1.
- Polish: T045, T046, T047.

## Parallel Example: User Story 1

```text
T014 LampTransitionTests.swift
T015 GlowRevealTests.swift
T016 RendererTests.swift (reference image, then L6)
```

## Implementation Strategy

### MVP first (US1)

1. Setup and Foundational.
2. US1: the lamp switch. Validate with Q1–Q4, Q12, Q13, Q15 on a real iPad.
3. Stop and review the reveal with the owner before polishing the rest.

### Incremental delivery

US1 → US2 → US3 → US4 → Polish. Each story is demoable on its own with the QA app; partner review
(T045) covers all new elements at once, before the pilot.

## Notes

- Nothing here changes the glow pattern, coverage, or colours from 001; only how it arrives.
- Face-guard blanking stays immediate in every story (FR-020).
- Commit after each task or logical group.
