---
description: "Task list for the UV Germ Visualization Study MVP"
---

# Tasks: UV Germ Visualization Study MVP

**Input**: Design documents from `/specs/001-uv-germ-visualization/`

**Prerequisites**: plan.md, spec.md, research.md (R1–R15), data-model.md, contracts/ (5),
quickstart.md (V1–V13), `.specify/memory/constitution.md` (v2.0.0)

**Tests**: Included. plan.md (Technical Context → Testing) requires unit tests for pattern
generation, anchoring, surface classification, the state machine, the logger, and the exporter,
and data-model.md lists validation rules as "unit tested". Within each story, write the tests
first and confirm they fail before implementing.

**Organization**: Tasks are grouped by user story so each story can be built and tested on its
own.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependency on an unfinished task)
- **[Story]**: US1 (See the invisible, P1), US2 (Run a study session, P2), US3 (Rehearse the
  wash, P3)
- Paths are relative to the repository root (`clean-hands/`)

## Path Conventions (from plan.md)

- App: `ios/CleanHands/<Module>/` with modules App, Camera, Tracking, Glow, Rendering, Flow,
  Audio, Study, Facilitator, Debug, Resources
- Unit tests: `ios/CleanHandsTests/<Module>/`
- Python tooling: `tools/`
- Study materials: `docs/protocol/`, `docs/instruments/`, `docs/narration/`, `docs/qa/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create the Xcode project and the shared resource files.

- [X] T001 Create the Xcode project `ios/CleanHands.xcodeproj` with app target `CleanHands`: Swift 6, SwiftUI lifecycle, iPad only, deployment target iPadOS 17.0, no third-party packages, and empty groups App, Camera, Tracking, Glow, Rendering, Flow, Audio, Study, Facilitator, Debug, Resources under `ios/CleanHands/`. Add a third build configuration `QA` (Release optimization plus the compile flag `QA_TOOLS`) with its own scheme, bundle ID suffix `.qa`, and a distinct app icon, so the test tools (T047, T052, T053) reach the centre's iPads through TestFlight as a separate app that is never used in sessions
- [X] T002 Add the unit test target `CleanHandsTests` (Swift Testing) with groups Glow, Tracking, Flow, Study in `ios/CleanHandsTests/`
- [X] T003 [P] Configure `ios/CleanHands/Info.plist`: `NSCameraUsageDescription` (Swahili and English), `UIRequiresFullScreen = YES`, a single supported interface orientation (locked; the iPad lies flat in setup A and auto-rotation would flip the screen), no background modes
- [X] T004 [P] Add `ios/CleanHands/CleanHands.entitlements` with Data Protection set to `NSFileProtectionComplete`, and confirm no network-related capabilities are enabled
- [X] T005 [P] Copy the `look.json` defaults verbatim from `specs/001-uv-germ-visualization/contracts/look-config.md` into `ios/CleanHands/Resources/look.json`
- [X] T006 [P] Create the string catalog `ios/CleanHands/Resources/Localizable.xcstrings` with languages `sw` (participant default) and `en` (facilitator), per research R15
- [X] T007 [P] Write `docs/narration/script.en.md` with clips N01–N21, copying the English source text verbatim from `contracts/ui-flow.md`, plus each clip's state, and the limits "≤ 12 s, except N04 and N19 (≤ 25 s)"
- [X] T008 [P] Add `ios/.gitignore` for Xcode build output (`DerivedData/`, `*.xcuserstate`, `xcuserdata/`)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Camera, hand tracking, rendering base, audio, flow skeleton, and safety controls
that every story needs.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [X] T009 [P] Implement `LookConfig` as a `Codable` struct that mirrors every key in `look.json` and loads it from the bundle, in `ios/CleanHands/Glow/LookConfig.swift`
- [X] T010 [P] Unit test that the bundled `look.json` decodes, `rehearsal.stepSeconds` sums to ≥ 20, and `glow.coverageTarget` is `{min 0.15, max 0.25}`, in `ios/CleanHandsTests/Glow/LookConfigTests.swift`
- [X] T011 [P] Define the runtime types `HandFrame` and `TrackedHand` exactly as in data-model.md (`chirality`: `left`, `right`, or `unknown`; `joints`: 21 × (x, y, confidence); `surface`: `palm`, `back`, or `edgeOn`; `scale`: wrist to middle-finger knuckle distance) and the `HandTracker` protocol, in `ios/CleanHands/Tracking/HandTracker.swift`
- [X] T012 [P] Implement `OneEuroFilter` (per-joint x/y, configurable min cutoff, beta, derivative cutoff) in `ios/CleanHands/Tracking/OneEuroFilter.swift`
- [X] T013 [P] Unit test `OneEuroFilter`: jitter on a still signal is damped, and a step change is followed within a bounded lag, in `ios/CleanHandsTests/Tracking/OneEuroFilterTests.swift`
- [X] T014 [P] Implement `CameraSetup` (`overheadRear` / `mirrorFront`, with the mirror flip flag for setup B, research R9) in `ios/CleanHands/Camera/CameraSetup.swift`
- [X] T015 Implement `CameraService` on AVFoundation: rear or front camera per `CameraSetup`, 30 fps target, frames delivered as `CVPixelBuffer` to a latest-frame-only consumer (older frames dropped, R8), no recording, no frame persistence, in `ios/CleanHands/Camera/CameraService.swift`
- [X] T016 Implement `VisionHandTracker: HandTracker` with `VNDetectHumanHandPoseRequest` (`maximumHandCount = 2`, chirality, latest frame only), applying `OneEuroFilter` per joint and interpolating low-confidence joints from neighbors, in `ios/CleanHands/Tracking/VisionHandTracker.swift`
- [X] T017 Implement `FaceGuard`: a `VNDetectFaceRectanglesRequest` at about 2 Hz on camera frames that publishes `faceVisible`, in `ios/CleanHands/Tracking/FaceGuard.swift`
- [X] T018 Implement the Metal base: `MetalCameraView` (MTKView wrapped for SwiftUI) and `Renderer` that converts camera frames to textures via `CVMetalTextureCache` and draws them in normal view (straight copy), with frame-time measurement, in `ios/CleanHands/Rendering/MetalCameraView.swift` and `ios/CleanHands/Rendering/Renderer.swift`
- [X] T019 [P] Write `tools/make_placeholder_narration.sh`, which generates placeholder clips `N01.m4a`–`N21.m4a` from `docs/narration/script.en.md` with macOS `say` + `afconvert` into `ios/CleanHands/Resources/Narration/` (development only, research R10)
- [X] T020 [P] Create `ios/CleanHands/Resources/narration-manifest.json` mapping each clip ID `N01`–`N21` to its file, English source, and an empty Swahili transcript field
- [X] T021 Implement `NarrationPlayer` on AVFAudio: play a clip by ID, replay the last clip, stop, and a `onClipPlayed(clipId)` callback, in `ios/CleanHands/Audio/NarrationPlayer.swift`
- [X] T022 Define `SessionState` with every state from data-model.md (idle, consentCheck, blocked, deviceReady, positioning, normalView, uvIntro, uvReveal, normalView2, quickRinseDemo, rehearsal(step), realWashPrompt, debrief, paused(reason), ended(outcome)) and implement `SessionStateMachine` with a transition table, `stop(by:)` from any state → `ended(aborted)`, a face-guard pause that returns to the previous state, and an `onTransition` observer, in `ios/CleanHands/Flow/SessionStateMachine.swift`
- [X] T023 [P] Unit test `SessionStateMachine`: illegal transitions are rejected, stop works from every state, and face-guard pause/resume returns to the previous state, in `ios/CleanHandsTests/Flow/SessionStateMachineTests.swift`
- [X] T024 [P] Implement the participant `StopButton` (red square icon, not a hand; no confirmation dialog) in `ios/CleanHands/Flow/Components/StopButton.swift`
- [X] T025 [P] Implement the facilitator `ControlStrip` (semi-transparent, on the screen edge furthest from the participant; Next, Back, Pause, Replay narration, End; never covers the hands view, FR-016) in `ios/CleanHands/Facilitator/ControlStrip.swift`
- [X] T026 Implement `AppModel` (`@Observable`: owns CameraService, HandTracker, FaceGuard, Renderer, NarrationPlayer, SessionStateMachine, LookConfig) and `CleanHandsApp` with the root `ParticipantRootView` that shows the camera view, StopButton, and ControlStrip on every screen, and blanks the camera plus plays N21 while `faceVisible`. On every camera screen except the rehearsal (which pauses with N16), when no hand is detected for more than 2 s it shows a pulsing hand outline and plays N02 (FR-009), in `ios/CleanHands/App/AppModel.swift`, `ios/CleanHands/App/CleanHandsApp.swift`, and `ios/CleanHands/Flow/ParticipantRootView.swift`

**Checkpoint**: The app shows the live camera on an iPad, tracks up to two hands, plays
narration, and can be stopped from any screen.

---

## Phase 3: User Story 1 - See the invisible (Priority: P1) 🎯 MVP

**Goal**: The live UV reveal: black background, dark violet hands, and a lime-green glow coating
anchored to each hand, with a palm/back pattern per hand, a view toggle, and the simulation
badge.

**Independent Test**: With 3 Swahili-speaking pilot volunteers outside the cohort, under the
session room's lighting, run US1 acceptance scenarios 1–8 (quickstart V3) using the DEBUG demo
launcher (T047). Glow appears within 2 s, stays off the background, follows the hand, and each
volunteer rates on the pictorial scale whether the marks looked attached.

### Tests for User Story 1 ⚠️

> Write these first and confirm they fail.

- [X] T027 [P] [US1] Unit test `SplitMix64` against published reference outputs for seeds 0 and 1234567, in `ios/CleanHandsTests/Glow/SplitMix64Tests.swift`
- [X] T028 [P] [US1] Unit test `PatternGenerator` per data-model.md validation rules: "The same seed gives an identical `marks` array"; "For each region, the left- and right-hand mark counts differ by at most 10%"; "The region distribution matches the weights in research R7, within sampling tolerance"; a `cap` "has exactly one per finger and thumb, per side"; palm and back patterns differ (FR-005); default counts "5 caps + 24 streaks + 220 flecks + 9 patches per hand side", in `ios/CleanHandsTests/Glow/PatternGeneratorTests.swift`
- [X] T029 [P] [US1] Unit test `Anchoring`: a `bone` anchor with `s ∈ [-0.7, 0.7]` always resolves inside the finger capsule; a `triangle` anchor with barycentric `u, v, w` resolves inside its triangle; anchors move with the joints under finger flexion and rotation (FR-003), in `ios/CleanHandsTests/Glow/AnchoringTests.swift`
- [X] T030 [P] [US1] Unit test `SurfaceClassifier`: the winding sign of wrist → index knuckle → little-finger knuckle for each chirality × `CameraSetup` combination gives the correct `palm`/`back`; a side change must persist about 150 ms before switching; triangle area below threshold gives `edgeOn` (research R5), in `ios/CleanHandsTests/Tracking/SurfaceClassifierTests.swift`
- [X] T031 [P] [US1] Unit test coverage on a fixed reference hand pose with a CPU rasterization of the marks: glow covers 15–25% of the hand, and "coverage by fifths, from the fingertips down, matches research R7 within ±10 percentage points" (about 60%, 25%, 13%, 8–10%), in `ios/CleanHandsTests/Glow/CoverageTests.swift`
- [X] T032 [P] [US1] Unit test `FadeState` appear/disappear: fade-in over `fadeInMs` (300) when a hand appears, fade-out over `fadeOutMs` (250) when lost, and a new `FadeState` starts every region at 1.0, in `ios/CleanHandsTests/Glow/FadeStateTests.swift`

### Implementation for User Story 1

- [X] T033 [P] [US1] Implement `SplitMix64` (own implementation, no system RNG, so patterns are stable across iPadOS versions, FR-006) in `ios/CleanHands/Glow/SplitMix64.swift`
- [X] T034 [P] [US1] Define `GlowPattern`, `GlowMark`, and `Anchor` per data-model.md: `hand` (`left` or `right`); `surface` (`palm` or `back`); `region` (`fingertip`, `thumb`, `interdigital`, `dorsalFinger`, `backOfHand`, `palmEdge`, `palm`, `wrist`); `kind` (`cap`, `streak`, `fleck`, or `patch`); `size` relative to the hand's `scale`; `intensity` 0…1; `hue` 0…1; `Anchor` = `bone(jointA, jointB, t ∈ [0,1], s ∈ [-0.7, 0.7])` or `triangle(j1, j2, j3, barycentric u, v, w)`, in `ios/CleanHands/Glow/GlowPattern.swift`
- [X] T035 [US1] Implement `PatternGenerator.generate(seed:config:)`: caps on every fingertip and thumb (extent and brightness ranges from `pattern.caps`), streaks along finger bones, flecks over fingers and palm edges, patches on heel, little-finger edge, thumb base, and back of hand; placement by `pattern.regionWeights`; the same weights for both hands; back-of-hand patches weighted toward the knuckles and between the fingers (research R7); wrist marks reach at most `pattern.wristExtent` (0.25 of hand scale) past the wrist joint, so they stay off sleeves, in `ios/CleanHands/Glow/PatternGenerator.swift`
- [X] T036 [US1] Implement `Anchoring.resolve(_:on:)` that turns an `Anchor` into an image-space point and local frame from a `TrackedHand`, estimating each finger's half-width from `scale`, with the palm/back triangles built from the wrist, thumb base, and four knuckle joints, in `ios/CleanHands/Glow/Anchoring.swift`
- [X] T037 [US1] Implement `SurfaceClassifier` (winding rule, chirality, `CameraSetup` sign convention, 150 ms hysteresis, `edgeOn` area threshold) and set `TrackedHand.surface` in the tracking pipeline, in `ios/CleanHands/Tracking/SurfaceClassifier.swift`
- [X] T038 [P] [US1] Implement `HandIdentity`, which keeps left/right identity by position continuity when chirality is `unknown` or flips, assigned once per appearance (research R5 fallback), in `ios/CleanHands/Tracking/HandIdentity.swift`
- [X] T039 [US1] Implement `FadeState`: a multiplier per `(hand, surface, region)` from 1.0 to 0.0, plus per-hand appear/disappear fades from `look.json` → `fade`; never persisted, in `ios/CleanHands/Glow/FadeState.swift`
- [X] T040 [US1] Implement `LightPool`: draw finger-bone capsules plus the palm polygon from the joints at low resolution, dilate by `uvView.lightPool.dilate` (0.15 of hand scale), blur by `lightPool.blur`, into a mask texture, cut off at `pattern.wristExtent` past the wrist joint so a sleeve is not lit (research R4), in `ios/CleanHands/Rendering/LightPool.swift`
- [X] T041 [US1] Write the skin pass in `ios/CleanHands/Rendering/Shaders.metal`: luma from the camera frame, light unsharp mask (`skinLocalContrast`), map onto `skinRamp` (black → dark violet, hue about 250°), multiply by the light pool, fall off to `#000000` outside; plus the faint nail tint at fingertip joints (`nailTint`)
- [X] T042 [US1] Add even exposure for every skin tone: measure mean luma inside the light pool at low resolution each frame and set a smoothed gain so mapped skin lands near `skinTargetValue` (0.24), in `ios/CleanHands/Rendering/Renderer.swift` and `ios/CleanHands/Rendering/Shaders.metal`
- [X] T043 [US1] Write the coverage pass: draw each resolved mark as a soft shape (cap, streak, fleck, patch) times `FadeState` into an offscreen coverage texture; multiply by a hand-fixed grain texture (`glow.grain`) and by a skin-detail term from the camera image (`skinDetailStrength`), so creases cut through the glow. The detail term is a fine high-pass band at crease scale with its amplitude clamped, so broad high-contrast patterns such as henna do not print into the glow (spec edge case), in `ios/CleanHands/Rendering/Shaders.metal` and `ios/CleanHands/Rendering/Renderer.swift`
- [X] T044 [US1] Write the bloom and composite passes: map coverage to `glow.palette` (low → peak) with `hueJitter`, add a very small bloom (`glow.bloom`), and composite over the skin pass; normal view stays a straight copy (FR-007), in `ios/CleanHands/Rendering/Shaders.metal` and `ios/CleanHands/Rendering/Renderer.swift`
- [X] T045 [US1] Implement `QualityController`: if frame time stays above budget, step `high → medium → low` per `look.json` → `quality` (`countScale`, `bloomScale`), and step back up with hysteresis; expose `onLevelChanged(level)`, in `ios/CleanHands/Rendering/QualityController.swift`
- [X] T046 [P] [US1] Implement `SimulationBadge` (lamp icon plus the Swahili label for "simulation" from `Localizable.xcstrings`), and show it from `ParticipantRootView` whenever the renderer reports glow on screen (UV view and any fade multiplier above 0), so every glow screen (reveal, quick rinse, rehearsal, real-wash prompt) carries it without per-screen code (FR-008, Principle I), in `ios/CleanHands/Flow/Components/SimulationBadge.swift` and `ios/CleanHands/Flow/ParticipantRootView.swift`
- [X] T047 [US1] Add a demo launcher, compiled only under `#if DEBUG || QA_TOOLS`, that starts the US1 flow with a fixed seed and no participant record, so US1 can be tested before US2 exists. After `uvReveal` it plays N19, so a reveal never ends without a concrete action (Principle V). It MUST NOT compile into the Release (study) build, in `ios/CleanHands/Debug/DemoLauncher.swift`
- [X] T048 [US1] Implement `PositioningView`: live camera, hand-outline icon and arrow, N01 on entry, advance to `normalView` when hands are detected (the no-hand guidance comes from `ParticipantRootView`, T026), in `ios/CleanHands/Flow/Screens/PositioningView.swift`
- [X] T049 [US1] Implement `NormalView` (N03) and `UVIntroView` (lamp icon, simulation badge, N04 played to completion before any glow appears, FR-008), in `ios/CleanHands/Flow/Screens/NormalView.swift` and `ios/CleanHands/Flow/Screens/UVIntroView.swift`
- [X] T050 [US1] Implement `UVRevealView`: UV render on, N05, then N06 with the turn-hand icon, then N07 with eye / lamp icon buttons that switch between normal and UV view at any time (FR-007); simulation badge always visible, in `ios/CleanHands/Flow/Screens/UVRevealView.swift`
- [X] T051 [US1] Wire the US1 states into `SessionStateMachine` and `ParticipantRootView` (positioning → normalView → uvIntro → uvReveal ⇄ normalView2), driven by the ControlStrip's Next/Back, in `ios/CleanHands/Flow/SessionStateMachine.swift` and `ios/CleanHands/Flow/ParticipantRootView.swift`
- [X] T052 [P] [US1] Implement the `ReplayHarness` (`#if DEBUG || QA_TOOLS`): import a test video from Files, run it through tracking and rendering, and write a report (time to first detection, per-frame detection rate, render fps, tracking Hz) plus an overlay export for the 20-pose spill check (SC-001, SC-002, research R14), in `ios/CleanHands/Debug/ReplayHarness.swift`
- [X] T053 [P] [US1] Implement the `TuningPanel` (`#if DEBUG || QA_TOOLS`) that edits `LookConfig` live and saves a new `look.json` to Files, in `ios/CleanHands/Debug/TuningPanel.swift`
- [ ] T054 [US1] Record replay clips with consenting non-participant volunteers (≥ 10 adult women matching the participant group's skin tones, ≥ 3 with henna, ≥ 3 with rings or bangles, session-room lighting, and a 20-pose script that includes at least 2 poses with sleeves covering the wrists) and log the clip inventory without images in `docs/qa/replay-clips.md` (SC-003)
- [ ] T055 [US1] Run gates 1–2 with the ReplayHarness and record SC-001 (≥ 95% within 2 s), SC-002 (≤ 1 of 20 poses spill), and SC-003 results in `docs/qa/gate-1-2-tracking.md`; if Vision fails, document it and open the MediaPipe fallback (research R3) before going further
- [ ] T056 [US1] Run gate 3 visual QA: tune with the TuningPanel, take screenshots of a volunteer's open palm, cupped hands, and back of the hand, plus an open palm with henna, run `python3 tools/measure_glow.py <shots> --bands`, collect the side-by-side verdict of 3 reviewers (owner plus 2 partner staff), confirm the henna design is not recognizable in the glow, commit the final `ios/CleanHands/Resources/look.json`, and record results (no screenshots) in `docs/qa/gate-3-visual.md`

**Checkpoint**: The reveal works on its own on a study iPad (DEBUG demo launcher). This is the
MVP demo.

---

## Phase 4: User Story 2 - Run a study session (Priority: P2)

**Goal**: Consent-gated sessions by participant code, the same pattern across sessions, a full
event log, a spoken debrief, pseudonymous export, withdrawal, and the paper materials for
baseline and follow-up.

**Independent Test**: Run 3 mock participants (`PIL-` codes) through Baseline, Session 1,
Session 2, and Follow-up in compressed time (quickstart V2, V4, V8, V9, V10). The camera never
starts without consent, every event is in the export, patterns match across sessions, and the
follow-up needs no app.

### Tests for User Story 2 ⚠️

> Write these first and confirm they fail.

- [ ] T057 [P] [US2] Unit test `Participant` and `ParticipantStore`: code must match "`^(ZNZ|PIL)-\d{2}$`, unique"; `consentRecorded` "Must be `true` before the camera can start (FR-017)"; `consentRecordedAt` set when consent becomes true; `patternSeed` "Generated once at registration. Never changes (FR-006)"; withdrawing deletes "all of this participant's sessions and events (FR-026)"; registry round-trips through disk, in `ios/CleanHandsTests/Study/ParticipantStoreTests.swift`
- [ ] T058 [P] [US2] Unit test `Session` rules: `participantCode` "Must reference an existing, non-withdrawn participant"; "A `session2` requires an earlier completed `session1`"; `abortReason` only set when `outcome` is `aborted`, in `ios/CleanHandsTests/Study/SessionRulesTests.swift`
- [ ] T059 [P] [US2] Unit test `EventLogger`: `seq` "Increases monotonically within a session, starting at 0"; `t` is ISO 8601 with milliseconds and a timezone offset; every written line validates against the required fields and per-type `data` of `contracts/session-event-log.schema.json`; a full session run through the state machine produces no `stateEntered` value outside the schema enum; the log is append-only, in `ios/CleanHandsTests/Study/EventLoggerTests.swift`
- [ ] T060 [P] [US2] Unit test `Exporter` on a fixture of 2 participants and 3 sessions: folder name `cleanhands-export-<deviceShortId>-<YYYYMMDD-HHmm>`, the five files, CSV columns exactly as in `contracts/export-format.md`, each `session_summary.csv` derivation, withdrawn participants absent, and no field containing a name, contact detail, or image data, in `ios/CleanHandsTests/Study/ExporterTests.swift`
- [ ] T061 [P] [US2] Unit test the consent gate: with consent not recorded, starting a session leaves `CameraService` stopped and the state machine in `blocked`, in `ios/CleanHandsTests/Flow/ConsentGateTests.swift`

### Implementation for User Story 2

- [ ] T062 [P] [US2] Implement `Participant` per data-model.md (`code`, `consentRecorded`, `consentRecordedAt`, `consentFormRef` — "Reference number of the paper consent form. Never a name.", `patternSeed: UInt64`, `withdrawn`, `createdAt`); no name, phone, village, or photo fields, in `ios/CleanHands/Study/Participant.swift`
- [ ] T063 [P] [US2] Implement `Session` per data-model.md (`id`, `participantCode`, `visit` `session1`/`session2`, `facilitatorCode` e.g. `F1` "Never a name", `cameraSetup`, `deviceModel`, `osVersion`, `appVersion`, `startedAt`, `endedAt`, `outcome` `completed`/`aborted`/`inProgress`, `abortReason` `participantStopped`/`facilitatorStopped`/`faceGuard`/`deviceIssue`/`other`), in `ios/CleanHands/Study/Session.swift`
- [ ] T064 [P] [US2] Implement `SessionEvent` and an `EventType` enum with exactly the 17 types in `contracts/session-event-log.schema.json`, with typed `data` payloads, in `ios/CleanHands/Study/SessionEvent.swift`
- [ ] T065 [US2] Implement `ParticipantStore`: JSON registry plus session records in the app sandbox, atomic writes with `.completeFileProtection`, register (generates `patternSeed` with `SecRandomCopyBytes`), record consent, list, withdraw (deletes the participant, sessions, and event logs), in `ios/CleanHands/Study/ParticipantStore.swift`
- [ ] T066 [US2] Implement `EventLogger`: one append-only JSON Lines file per session with `.completeFileProtection`, monotonic `seq`, ISO 8601 ms timestamps with offset, in `ios/CleanHands/Study/EventLogger.swift`
- [ ] T067 [US2] Connect logging: every transition into a state listed in the schema's `stateEntered` enum writes `stateEntered` (`idle` and `ended` are covered by `sessionStarted`/`sessionEnded`, and `normalView2` by `viewSwitched`); also `sessionStarted`, `consentVerified`, `handsDetected`/`handsLost` (with `msSinceStateEntered`), `viewSwitched`, `narrationPlayed`, `faceGuardTriggered`/`faceGuardCleared`, `qualityLevelChanged`, `debriefShown`, `sessionEnded` with outcome and reason, in `ios/CleanHands/App/AppModel.swift` and `ios/CleanHands/Flow/SessionStateMachine.swift`
- [ ] T068 [US2] Implement the consent gate: `consentCheck` → `blocked` when consent is not recorded, and `CameraService.start()` refuses to run without a consented, non-withdrawn participant (FR-017), except for the demo launcher (T047) under `#if DEBUG || QA_TOOLS`, in `ios/CleanHands/Flow/SessionStateMachine.swift` and `ios/CleanHands/Camera/CameraService.swift`
- [ ] T069 [US2] Implement `SettingsPanel`, opened by a two-finger long press (2 s) on the ControlStrip, blanking the camera view while open; sections for participants, camera setup A/B, Device Check, export, and withdrawal; Swahili and English, in `ios/CleanHands/Facilitator/SettingsPanel.swift`
- [ ] T070 [P] [US2] Implement `ParticipantRegistrationView`: register a code (`ZNZ-xx` / `PIL-xx`, validated), record consent with the paper form reference; no name or contact fields (FR-018), in `ios/CleanHands/Facilitator/ParticipantRegistrationView.swift`
- [ ] T071 [P] [US2] Implement `SessionStartView`: pick participant code, facilitator code (`^F\d{1,2}$`), and visit (`session2` only after a completed `session1`, FR-019); show consent status; start loads the participant's `patternSeed` into the pattern, in `ios/CleanHands/Facilitator/SessionStartView.swift`
- [ ] T072 [P] [US2] Implement `DeviceCheckView`: model, iPadOS version, measured render fps and tracking Hz, camera available, battery level with a low-battery warning before start, and every narration clip N01–N21 present (`NarrationPlayer.missingClips()`; a session cannot start without them, 002 FR-004b); logs `deviceCheck` (research R2, quickstart V1), in `ios/CleanHands/Facilitator/DeviceCheckView.swift`
- [ ] T073 [P] [US2] Implement `DebriefView` (lamp icon then hands icon, N19, logs `debriefShown`, FR-021) and `AbortedView` (calm screen; the camera stops at once; if the session reached `uvIntro`, it plays N19 then N20 and logs `debriefShown`, otherwise N20 only, FR-021), in `ios/CleanHands/Flow/Screens/DebriefView.swift` and `ios/CleanHands/Flow/Screens/AbortedView.swift`
- [ ] T074 [US2] Wire the US2 flow: idle → consentCheck → deviceReady → positioning, uvReveal → debrief → ended(completed) (US3 later inserts its states before debrief); Stop and End → aborted with the right `abortReason`; face guard → `paused(faceGuard)` with N21, in `ios/CleanHands/Flow/SessionStateMachine.swift`
- [ ] T075 [US2] Implement `Exporter`: build the export folder with `manifest.json`, `participants.csv`, `sessions.csv`, `events.jsonl`, and `session_summary.csv` (duration_s, time_to_first_hand_ms, uv_view_seconds, view_switch_count, steps_completed, rehearsal_active_s, pause_count, face_guard_count, min_quality_level) per `contracts/export-format.md`; export never deletes data, in `ios/CleanHands/Study/Exporter.swift`
- [ ] T076 [US2] Implement `ExportView` (share sheet: AirDrop, Files, USB-C) and `WithdrawView` (withdraw by code with a facilitator confirmation), in `ios/CleanHands/Facilitator/ExportView.swift` and `ios/CleanHands/Facilitator/WithdrawView.swift`
- [ ] T077 [P] [US2] Write `tools/validate_export.py`: validate every line of `events.jsonl` against `contracts/session-event-log.schema.json` with `jsonschema`, check CSV headers against `contracts/export-format.md`, and flag any column that looks like a name or contact detail (quickstart V9)
- [ ] T078 [P] [US2] Write the study protocol and pre-registration draft (design, visits, 5-day app-free period with no reminders or app access per FR-025, primary and secondary outcomes from `contracts/measures.md`, pilot exclusion of `PIL-` data) in `docs/protocol/study-protocol.md` and `docs/protocol/pre-registration.md`, and the data management plan (lawful basis, retention period, deletion procedure covering the iPads, paper forms, `measures.csv`, and exports already shared, named data controller, and the key linking codes to people stored separately and kept by the partner) in `docs/protocol/data-management-plan.md`
- [ ] T079 [P] [US2] Write the consent script in English for translation (oral Swahili explanation, voluntariness, no effect on Solar Mamas or Enriche standing, data handling, withdrawal by code, optional audio recording consent) in `docs/protocol/consent-script.en.md`
- [ ] T080 [P] [US2] Write the facilitator script (session steps, ControlStrip use, answer to "is this real?", follow-up interview order, real UV tracer demonstration at the end of follow-up per FR-024, data-handling rules) in `docs/protocol/facilitator-script.md`
- [ ] T081 [P] [US2] Produce the printable instruments from `contracts/measures.md`: key-moment cards K1–K5, frequency card, hand-outline card (zones Z1–Z6), vividness card, attached-rating picture scale (0–4), and the demonstration checklist, in `docs/instruments/` (one file per card)
- [ ] T082 [P] [US2] Create the measures data-entry template with exactly the columns of `contracts/measures.md` in `docs/instruments/measures-template.csv`

**Checkpoint**: A mock participant can be registered, consented, run through two sessions with
the same pattern, exported, and withdrawn; the follow-up runs entirely on paper.

---

## Phase 5: User Story 3 - Rehearse the wash (Priority: P3)

**Goal**: The quick-rinse demonstration, then six guided rubbing motions without water that fade
the matching regions, ending with an invitation to wash for real.

**Independent Test**: 3 pilot volunteers follow the rehearsal (quickstart V5). Each step advances
only while both hands are in view, pauses after 1 s without them and resumes, matching regions
fade, and the log shows ≥ 20 s of active rubbing.

### Tests for User Story 3 ⚠️

> Write these first and confirm they fail.

- [ ] T083 [P] [US3] Unit test `RehearsalPlan`: six steps in WHO order, durations from `rehearsal.stepSeconds` (default 4, 5, 4, 4, 4, 4 = 25 s ≥ 20 s), and the step → region map (1 palm + palmEdge, 2 backOfHand, 3 interdigital, 4 dorsalFinger, 5 thumb, 6 fingertip), in `ios/CleanHandsTests/Flow/RehearsalPlanTests.swift`
- [ ] T084 [P] [US3] Unit test `RehearsalController` with a fake clock: progress advances only with 2 hands; a loss shorter than 1 s does not pause or reset; a loss longer than `pauseAfterMs` (1000) pauses; progress resumes when both hands return; `activeSeconds` counts only active time (FR-011), in `ios/CleanHandsTests/Flow/RehearsalControllerTests.swift`
- [ ] T085 [P] [US3] Unit test rehearsal fading: quick rinse leaves `palm` at 0.3 and nothing else changed; completing step n brings its regions to 0 and leaves others; wrist ends at 0.5 after all six steps (FR-012), in `ios/CleanHandsTests/Glow/RehearsalFadeTests.swift`

### Implementation for User Story 3

- [ ] T086 [P] [US3] Implement `RehearsalPlan` (steps, durations from `LookConfig`, regions per step, clip IDs N10–N15) in `ios/CleanHands/Flow/RehearsalPlan.swift`
- [ ] T087 [US3] Implement `RehearsalController`: time-based progress while both hands are in view, pause after `pauseAfterMs`, resume, per-step `activeSeconds`, events `stepStarted`/`stepPaused`/`stepResumed`/`stepCompleted`, in `ios/CleanHands/Flow/RehearsalController.swift`
- [ ] T088 [US3] Extend `FadeState` with `applyQuickRinse()` (palm → `fade.quickRinse.palm`) and `applyStepProgress(step:fraction:)` (step regions → 0, wrist spread to `wristPerRehearsal`), in `ios/CleanHands/Glow/FadeState.swift`
- [ ] T089 [P] [US3] Create six looping demonstration animations of the WHO motions (illustrated hands, no photos of people), in `ios/CleanHands/Resources/Assets.xcassets/Demos/`
- [ ] T090 [P] [US3] Implement `QuickRinseDemoView`: palm-centre glow fades over a few seconds while N08 plays ("most people", never "you", FR-013), in `ios/CleanHands/Flow/Screens/QuickRinseDemoView.swift`
- [ ] T091 [US3] Implement `RehearsalView`: N09 intro with a demo loop, then per step the demo animation, N10–N15, and a progress indicator; N16 with the two-hands icon while paused; N17 when done; glow visible with the simulation badge, in `ios/CleanHands/Flow/Screens/RehearsalView.swift`
- [ ] T092 [P] [US3] Implement `RealWashPromptView` (soap-and-water icon, N18; wudu framed as complementary, FR-015) in `ios/CleanHands/Flow/Screens/RealWashPromptView.swift`
- [ ] T093 [US3] Wire the US3 states: uvReveal → quickRinseDemo → rehearsal(1…6) ⇄ paused(step n) → realWashPrompt → debrief, in `ios/CleanHands/Flow/SessionStateMachine.swift` and `ios/CleanHands/Flow/ParticipantRootView.swift`

**Checkpoint**: The full session (reveal → rinse demo → rehearsal → real wash → debrief) runs
end to end, and `session_summary.csv` reports `steps_completed` and `rehearsal_active_s`.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Swahili content, constitution gates, deployment, and the pilot.

- [ ] T094 [P] Translate `docs/narration/script.en.md` into `docs/narration/script.sw.md` (native speaker), add the back-translation in `docs/narration/script.backtranslation.md`, and resolve differences
- [ ] T095 [P] Translate the consent script into `docs/protocol/consent-script.sw.md` with back-translation
- [ ] T096 Fill the Swahili strings (simulation label, facilitator labels) in `ios/CleanHands/Resources/Localizable.xcstrings` and the Swahili transcripts in `ios/CleanHands/Resources/narration-manifest.json`
- [ ] T097 Replace the placeholder clips with the partner-approved voice recordings in `ios/CleanHands/Resources/Narration/` and check every clip's length against the limits in `contracts/ui-flow.md`
- [ ] T098 [P] Write `tools/check_no_networking.sh`, which greps `ios/CleanHands/` for `URLSession`, `import Network`, `WKWebView`, `SFSafariViewController`, and `NWConnection`, and fails on any hit (quickstart V11, gate 4)
- [ ] T099 [P] Verify the Release (study) build excludes `ios/CleanHands/Debug/` (DemoLauncher, ReplayHarness, TuningPanel) and that the release binary has no symbols from them; record in `docs/qa/release-build-check.md`
- [ ] T100 [P] Write the device setup guide (TestFlight install, Airplane Mode, passcode, Guided Access, setup A stand or setup B mirror clip, matte dark cloth) in `docs/protocol/device-setup.md`
- [ ] T101 Resolve open items and record decisions in `specs/001-uv-germ-visualization/research.md`: iPad models and iPadOS versions (raise the deployment target in `ios/CleanHands.xcodeproj` if all are A12+), camera setup A or B, and wrist handling in the rehearsal
- [ ] T102 Run quickstart V1–V12 on every study iPad in the session room (V6 with the QA app from T001) and record pass/fail per scenario in `docs/qa/validation-log.md`
- [ ] T103 Run V13: partner staff review the full session with final Swahili audio; record sign-off and any concerns in `docs/qa/gate-5-cultural-review.md`
- [ ] T104 Run the pilot with 2–3 Swahili-speaking non-cohort volunteers (`PIL-` codes), including the privacy check with network off (gate 4, SC-007), and record findings and changes in `docs/qa/pilot-report.md`
- [ ] T105 Finalize and time-stamp `docs/protocol/pre-registration.md` before the first `ZNZ` session
- [ ] T106 Complete the approvals checklist in `docs/protocol/approvals.md`: ethics approval(s) per TODO(ETHICS_BODY) (ZAHREC and the researcher's home institution), written permission from Barefoot College International Zanzibar, the approved form of consent (signature, thumbprint, or witnessed oral), printed Swahili consent materials, and the data management plan from T078; no `ZNZ` session until every item is signed off

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: no dependencies.
- **Foundational (Phase 2)**: depends on Setup; blocks all user stories.
- **US1 (Phase 3)**: depends on Foundational only.
- **US2 (Phase 4)**: depends on Foundational. Its flow ends at `uvReveal → debrief`, so for a
  meaningful run it also uses US1's screens (T048–T051); its models, store, logger, exporter,
  and paper materials (T057–T066, T075–T082) can be built in parallel with US1.
- **US3 (Phase 5)**: depends on US1 (glow, `FadeState`, reveal states). Logging of its step
  events needs US2's `EventLogger` (T066).
- **Polish (Phase 6)**: depends on all stories. T094–T095 and T100 can start as soon as their
  source documents exist (T007, T079).

### User Story Dependencies

```text
Setup → Foundational ─┬─▶ US1 (P1) ─┬─▶ US3 (P3) ─┐
                      │             │             ├─▶ Polish
                      └─▶ US2 (P2) ─┴─────────────┘
```

### Within Each User Story

- Tests first, failing.
- Types and pure logic (Glow, Tracking math, Study models) → rendering and stores → screens →
  flow wiring → on-device validation.
- `Shaders.metal`, `Renderer.swift`, `SessionStateMachine.swift`, and `FadeState.swift` are
  shared files: tasks that touch them run in order.

### Parallel Opportunities

- Setup: T003–T008 together.
- Foundational: T009–T014, T019–T020, T023–T025 together.
- US1: all tests T027–T032; then T033, T034, T038, T046, T052, T053.
- US2: all tests T057–T061; models T062–T064; views T070–T073; docs T077–T082 (these can start
  any time after Phase 2, even before US1).
- US3: all tests T083–T085; then T086, T089, T090, T092.

---

## Parallel Example: User Story 1

```text
# Tests together:
T027 SplitMix64Tests.swift
T028 PatternGeneratorTests.swift
T029 AnchoringTests.swift
T030 SurfaceClassifierTests.swift
T031 CoverageTests.swift
T032 FadeStateTests.swift

# Independent implementation files together:
T033 Glow/SplitMix64.swift
T034 Glow/GlowPattern.swift
T038 Tracking/HandIdentity.swift
T046 Flow/Components/SimulationBadge.swift
T052 Debug/ReplayHarness.swift
T053 Debug/TuningPanel.swift
```

## Parallel Example: User Story 2

```text
# Tests together: T057, T058, T059, T060, T061
# Models together: T062 Participant.swift, T063 Session.swift, T064 SessionEvent.swift
# Paper materials together (no app dependency): T078, T079, T080, T081, T082
```

## Parallel Example: User Story 3

```text
# Tests together: T083, T084, T085
# Then together: T086 RehearsalPlan.swift, T089 demo animations, T090 QuickRinseDemoView.swift, T092 RealWashPromptView.swift
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1 Setup, Phase 2 Foundational.
2. Phase 3 US1, through gates 1–3 (T055, T056).
3. **Stop and validate**: the reveal on a study iPad with the DEBUG demo launcher. This answers
   the riskiest question first: is the glow convincing and stable on the participants' hands?
   If gate 2 fails, switch tracker (research R3) before building anything else.

### Incremental Delivery

1. US1 → demo the reveal to the owner and partner staff.
2. US2 → mock study visits with `PIL-` codes; paper materials ready.
3. US3 → full session; time it against SC-006 (≤ 15 min).
4. Polish → Swahili content, gates 4–5, pilot, pre-registration, then the first `ZNZ` session.

### Constitution reminders

- No real participant session before ethics approval (TODO(ETHICS_BODY)), partner permission,
  and the pilot (T104, T106).
- No networking code anywhere (T098); no camera frame is ever stored (QA screenshots and replay
  clips only from consenting test volunteers).
- Every glow screen carries the simulation badge; wording is always "most people".

## Notes

- [P] tasks touch different files and have no dependency on unfinished tasks.
- Commit after each task or logical group.
- Stop at any checkpoint to validate a story on its own.
- Open items owned by the owner or partner (iPad models, Swahili voice and reviewer, setup A/B,
  wrist handling) are tracked in T101 and do not block development.
