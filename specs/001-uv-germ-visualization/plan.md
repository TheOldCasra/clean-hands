# Implementation Plan: UV Germ Visualization Study MVP

**Branch**: `001-uv-germ-visualization` | **Date**: 2026-11-03 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/001-uv-germ-visualization/spec.md`

## Summary

An offline iPad app for a facilitator-led study with 8 Enriche participants at Barefoot College
International Zanzibar.

**What the participant sees**: her own hands, live, under a simulated "UV lamp". The background
goes black, her skin turns dark violet, and a lime-green fluorescent coating appears. The coating
is concentrated where people usually miss when washing, and it follows her real skin creases. A
guided rehearsal of the six WHO rubbing motions follows, and the glow fades region by region. All
narration is in Swahili.

**Technical approach**:
- **Hand tracking**: Apple Vision's on-device hand pose model, behind a swappable tracker
  interface. Fallbacks: MediaPipe, then a custom model (research R3).
- **Glow placement**: no segmentation model. Glow marks and a soft "lamp light" around the hands
  are both built from the 21 hand joints (R4).
- **Rendering**: Metal, four passes, tuned through `look.json` against the owner's reference
  images (R6, R7).
- **Study data**: local files only, exported by share sheet.
- **Measures**: on paper, so the app-free follow-up stays app-free (R11, R12).

## Technical Context

**Language/Version**: Swift 6 (current stable Xcode); Metal Shading Language

**Primary Dependencies**: Apple frameworks only: SwiftUI, AVFoundation (camera), Vision (hand
pose, face guard), Metal/MetalKit, AVFAudio. No third-party packages; MediaPipe is a fallback
only if gate 2 fails.

**Storage**: JSON registry + JSON Lines event logs in the app sandbox, with complete file
protection; export via the iPadOS share sheet.

**Testing**:
- Unit tests (Swift Testing / XCTest) for pattern generation, anchoring, surface
  classification, the state machine, the logger, and the exporter.
- A debug-only replay harness on recorded test clips, for gates 1–2.
- `tools/measure_glow.py` and a side-by-side review, for gate 3.
- Export validated against the JSON Schema with Python `jsonschema`.
- Manual device QA following [quickstart.md](quickstart.md).

**Target Platform**:
- iPadOS 17.0+ (raise if all centre iPads have an A12 chip or newer), iPad only.
- Interface orientation locked: in the overhead setup the iPad lies flat, and auto-rotation would
  flip the screen.

**Project Type**: Mobile app (single iPad app) plus study materials (docs).

**Performance Goals**:
- Render at display rate: 60 fps on A12+, ≥ 30 fps on A10.
- Hand tracking ≥ 15 Hz (target 30).
- Glow visible ≤ 2 s after a hand appears (SC-001).
- No visible lag between hand and glow; adaptive quality steps down before lag appears.

**Constraints**:
- Fully offline; no networking code; camera frames never saved.
- Usable without reading; Swahili audio; faces never in frame.
- Session ≤ 15 min (SC-006).
- Must work under the session room's lighting and for darker skin tones, henna, and jewelry
  (SC-003).

**Scale/Scope**:
- People: 8 participants plus 3–5 pilot volunteers, ≤ 2 sessions each (about 25 sessions).
- Hardware: 1–3 iPads.
- App size: about 12 flow states, 21 narration clips, 1 facilitator panel.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design.*

| Principle | Status | How the plan complies |
|---|---|---|
| I. Truthful Simulation | ✅ | Simulation badge on every glow screen; spoken explanation before the reveal (N04); "most people" wording (N05, N08); debrief (N19); real UV tracer demo at follow-up (FR-024) |
| II. Privacy by Design | ✅ | No networking code (V11); frames processed in memory only; pseudonymous codes; file protection; Airplane Mode in sessions; replay clips recorded outside the app from consenting volunteers only (R14) |
| III. Research Validity First | ✅ | Identical paper measures at baseline and follow-up ([contracts/measures.md](contracts/measures.md)); every state change logged (event schema); no reminders (FR-025); pre-registration before the first `ZNZ` session |
| IV. Pretrained Models First | ✅ | Apple Vision first; MediaPipe second; custom model only after a documented gate failure; participant-matched evaluation set (R3, R14) |
| V. Motivate, Don't Frighten | ✅ | Green "coating", no bugs or dirt language; every reveal ends in a positive action (N17–N19); Stop on every screen without confirmation |
| VI. MVP Simplicity | ✅ | Apple frameworks only; files instead of a database; paper measures; additions justified in Complexity Tracking below |
| VII. Culturally Grounded & Accessible | ✅ | Swahili audio by a partner-approved female voice; icon-first UI; wudu never framed as inadequate (N18); hands-only camera setups plus face guard; partner sign-off (V13) |

**Post-design re-check (after Phase 1)**: ✅ all principles still pass. The switch to a
references-matched look (near-black background, violet skin, glow textured by real skin creases)
adds no data retention: the skin detail is computed per frame in GPU memory and discarded.

## Project Structure

### Documentation (this feature)

```text
specs/001-uv-germ-visualization/
├── spec.md
├── plan.md              # This file
├── research.md          # Phase 0: decisions R1–R15
├── data-model.md        # Phase 1
├── quickstart.md        # Phase 1: validation scenarios V1–V13
├── contracts/
│   ├── session-event-log.schema.json
│   ├── export-format.md
│   ├── measures.md
│   ├── ui-flow.md
│   └── look-config.md
├── checklists/requirements.md
└── tasks.md             # Phase 2 (/speckit-tasks, not created here)
```

### Source Code (repository root)

```text
ios/
├── CleanHands.xcodeproj
├── CleanHands/
│   ├── App/            # App entry, app model, orientation lock
│   ├── Camera/         # Capture session, camera setup A/B (rear overhead / mirrored front)
│   ├── Tracking/       # HandTracker protocol, VisionHandTracker, OneEuroFilter,
│   │                   # SurfaceClassifier (palm/back), FaceGuard
│   ├── Glow/           # SplitMix64, PatternGenerator, Anchoring, FadeState, LookConfig
│   ├── Rendering/      # Renderer, LightPool, Shaders.metal (skin, coating, bloom, composite)
│   ├── Flow/           # SessionStateMachine, RehearsalPlan, participant screens
│   ├── Audio/          # NarrationPlayer + clip manifest
│   ├── Study/          # ParticipantStore, EventLogger, Exporter
│   ├── Facilitator/    # Discreet control strip, settings panel, Device Check
│   ├── Debug/          # ReplayHarness, TuningPanel (compiled only in DEBUG)
│   └── Resources/      # look.json, narration-manifest.json, Narration/*.m4a,
│                       # Localizable.xcstrings (sw, en), Assets.xcassets (icons)
└── CleanHandsTests/    # Unit tests for Glow, Tracking math, Flow, Study

tools/
├── measure_glow.py     # Gate 3 measurement (present)
└── validate_export.py  # V9 schema check

docs/
├── reference/          # Owner's reference images (git-ignored) + README with measurements
├── protocol/           # Study protocol, pre-registration, consent script (sw/en),
│                       # facilitator script
├── instruments/        # Key-moment cards, hand-outline card, scoring sheets (print)
└── narration/          # script.en.md → script.sw.md (translation + back-translation)
```

**Structure Decision**: one native iPad app under `ios/`, Python tooling under `tools/`, and
study materials under `docs/`. There is no backend: the constitution forbids networking, and
the study needs none.

## Complexity Tracking

> Constitution Principle VI requires justifying additions beyond the simplest build.

| Addition | Why Needed | Simpler Alternative Rejected Because |
|---|---|---|
| `HandTracker` protocol (one adapter now, a second only if needed) | Gate 2 may force a swap to MediaPipe or a custom model (Principle IV) | Hard-coding Vision would make a gate failure a rewrite |
| Two camera setups (A overhead / B mirror) | Hands-only framing depends on the centre's iPad models and furniture (Principle VII) | A single setup may not fit an unknown model; the cost is one flip flag and one calibration |
| Debug replay harness + tuning panel | Gates 1–3 need repeatable measurement and look tuning against references | Live-only testing is not repeatable; both are excluded from release builds |
| Face guard (a second Vision request at ~2 Hz) | Backup for Principle VII if someone leans into frame | Relying on the setup alone leaves no protection against mistakes |
| Hand light pool (low-res mask from joints) | References demand a black background with violet hands | Darkening the whole frame would turn a light table violet and lose darker skin against the background |

## Phase Status

- [x] Phase 0: research.md (R1–R15, all unknowns resolved or listed as owner/partner actions)
- [x] Phase 1: data-model.md, contracts/ (5), quickstart.md; Constitution Check re-passed
- [ ] Phase 2: `/speckit-tasks`
