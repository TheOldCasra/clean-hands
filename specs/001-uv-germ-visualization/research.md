# Research: UV Germ Visualization Study MVP

**Feature**: `001-uv-germ-visualization` | **Date**: 2026-11-03 | **Plan**: [plan.md](plan.md)

Each entry: Decision, Rationale, Alternatives considered. Items marked **ACTION** need input from
the project owner or partner before or during implementation.

---

## R1. Platform and language

**Decision**: Native iPadOS app in Swift (current Xcode), SwiftUI for screens, MetalKit for the
camera view and glow rendering.

**Rationale**:
- Sessions use only iPads, so cross-platform reach has no value here.
- Native gives direct access to Apple's on-device hand model (R3), full camera control (rear
  camera, frame rate, exposure), and stable GPU rendering (R6), all fully offline.
- Reliable local audio playback and file protection for study data come for free.

**Alternatives considered**:
- *Offline web app (PWA) in Safari with MediaPipe Hand Landmarker for Web*: no Mac or Apple
  developer account needed and easy to distribute by link. Rejected as primary because of weaker
  camera control, lower and less predictable performance on older iPads, audio autoplay limits,
  and the risk that Safari evicts website storage. **Kept as the fallback** if the owner has no
  Mac (see R13).
- *Flutter / React Native*: an extra layer between the camera, the ML model, and the GPU, with no
  benefit for an iPad-only study.

**Prerequisite (confirmed 2026-11-03)**: the owner has a Mac with Xcode and an Apple Developer
Program membership. The PWA fallback is not needed.

---

## R2. Minimum OS and the unknown iPad model

**Decision**: Deployment target iPadOS 17.0. Add a Device Check screen for the facilitator that
shows the model, OS version, measured render rate, and hand-tracking rate. Quality adapts
automatically: number of glow marks and bloom resolution step down if frame time is too high.

**Rationale**:
- iPadOS 17 still runs on fairly old iPads (from the A10-based iPad 6th generation), so the app
  covers whatever the centre has. iPadOS 26 requires an A12 chip or newer, and Apple dropped the
  iPad 7th generation with it.
- iPadOS 17 provides SwiftUI's `@Observable`, which simplifies state handling.
- Performance between an A10 iPad and an M-series iPad differs several-fold, so the app must
  measure and adapt rather than assume.

**Alternatives considered**: iPadOS 18 or 26 as target (cleaner APIs, e.g. the Swift-native
Vision requests from iPadOS 18) would exclude older iPads that a training centre may well have.

**ACTION**: Ask the centre for the exact model of each iPad (Settings → General → About → Model
Name) and its iPadOS version. If every iPad has an A12 chip or newer, raise the target to iPadOS
18 or later.

---

## R3. Hand tracking model (Principle IV: pretrained first)

**Decision**: Apple Vision's hand pose request (`VNDetectHumanHandPoseRequest`) as the primary
tracker, behind a small `HandTracker` protocol so a second tracker can be swapped in.

**Rationale**:
- It is a pretrained model built into iPadOS (available since iOS/iPadOS 14). It runs on device,
  needs no model files or third-party packages, and works offline.
- It returns 21 hand joints per hand. It detects up to 2 hands by default (largest first), and
  since iPadOS 15 it also reports left/right (chirality). That covers anchoring, two hands, and
  palm/back logic (R5).

**Fallback 1**: Google MediaPipe Hand Landmarker for iOS. Its published model card includes a
fairness evaluation across six skin-tone types, with no error pattern found by skin tone. It is
the first alternative if Vision fails the participant-group check (SC-003). Check the packaging
options (CocoaPods / Swift Package) at that time.

**Fallback 2 (custom model, last resort)**: use SAM 3 offline, with the text prompt "hand", to
auto-label frames from consenting test volunteers. Train a small on-device hand segmentation or
keypoint model on those labels, export to Core ML, and plug it into the `HandTracker` protocol.
SAM 3 itself is too heavy for live use on an iPad.

**Alternatives considered**: running SAM 3 / EfficientSAM3 live (too heavy or too immature for
real-time use on older iPads); ARKit (no hand tracking on iPad).

**Gate**: The choice is final only after the evaluation harness (R14) shows SC-001 to SC-003 are
met on hands that match the participant group.

---

## R4. Keeping the glow on the hand: no segmentation model

**Decision**: Do not segment hand pixels with a model. Everything is built from the 21 joints.

1. **Glow marks** are anchored in the hand's own coordinate system:
   - On a finger: a position along a bone, plus a sideways offset limited to about 70% of the
     finger's estimated half-width.
   - On the palm or back of the hand: a position inside one of the triangles formed by the wrist
     and the knuckle joints.

   Details in [data-model.md](data-model.md), `Anchor`.
2. **Hand light pool**: the references show the lit hands on a pure black background. The app
   draws the hand shape from the joints (a capsule for each finger bone, plus the palm polygon) at
   low resolution, dilates it by about 15% of the hand's size, and blurs it heavily.
   - Inside the pool, the camera image gets the violet skin treatment (R6). Outside, it falls off
     to black.
   - The edge is soft on purpose: it reads as the lamp lighting the hands (like the circular
     falloff in ref-02), so it does not need to be pixel-exact.
3. **Setup**: a matte dark cloth on the table, so the background inside the pool also stays dark.

**Rationale**:
- Marks stay inside the hand by construction and follow finger flexion (FR-003).
- Neither the marks nor the light pool depend on skin color, which removes a classic source of
  bias (Principle IV).
- It saves the time and frame budget a segmentation model would cost on older iPads.

**Alternatives considered**:
- *Apple person segmentation or foreground instance masks*: behavior on overhead views of only
  hands is unknown. Kept as a later refinement for crisper skin edges, only if visual QA against
  the references fails.
- *MediaPipe multi-class selfie segmenter (body-skin class)*: slow (about 70 ms per frame on GPU
  on a Pixel 6) and has a reported category mix-up bug on iOS Safari with GPU.
- *Color-based skin detection*: unreliable across skin tones and lighting, and fails with henna.

---

## R5. Palm or back facing the camera

**Decision**: Determine which side faces the camera from the hand's chirality and the winding
direction of the wrist → index knuckle → little-finger knuckle triangle in the image.
- **Hysteresis**: a side change must persist for about 150 ms before the pattern switches.
- **Edge-on hands**: when the triangle's area falls below a threshold (hand seen side-on), glow
  fades out instead of flickering.
- **Calibration**: the sign convention depends on camera setup (R9: rear camera vs. mirrored
  front camera) and is fixed by a unit test plus an on-device check.

**Rationale**: cheap, deterministic, and testable.

**Alternatives considered**: using the joints' depth estimates (noisier); a classifier
(unnecessary).

**Fallback if chirality is unreliable from overhead views**: keep hand identity by position
continuity, and assign left/right once per appearance.

---

## R6. Rendering the blacklight look (matched to the owner's references)

**Decision**: Metal, four passes per frame. Targets come from `docs/reference/README.md`.

1. **Skin under UV**
   - Inside the hand light pool (R4), convert the camera frame to brightness. Add local contrast
     (a light unsharp mask) so creases and fingerprint ridges stay visible, as in both references.
   - Map the result onto a ramp from black to dark violet (hue about 250°, top value about 0.35).
   - Outside the pool, fade to pure black.
   - In the normal view, this pass is a straight copy of the camera image.
2. **Even exposure for every skin tone**: measure the average brightness inside the pool at low
   resolution and set a gain so the mapped skin always lands near the reference skin value
   (about 0.23–0.24). Under real UV light, all skin looks dark violet. Doing the same here makes
   the effect look alike for every participant and keeps darker skin from sinking into the
   background.
3. **Glow coating**
   - Anchored marks (R7) are drawn as soft shapes into an offscreen coverage texture.
   - A grain texture, fixed to the hand so it never swims, breaks them into a powdery look.
   - Coverage is then multiplied by a detail term from the camera image, so creases and ridges
     cut through the glow. The glow takes on the participant's own skin texture and reads as
     *on her hand*, not floating above it.
   - Color: lime to mint green, median `#5a7c55`–`#508661` rising to `#8dce7b`–`#80df90` at the
     brightest coverage.
4. **Halo**: a very small, low-intensity bloom. Both references show almost no halo, so the
   earlier "soft halo" idea is dropped.

All parameters (palette, densities, grain, detail strength, bloom, pool size) live in
`look.json`; see [contracts/look-config.md](contracts/look-config.md). Matching the references is
a tuning task, and gate 3 compares side-by-side screenshots against them.

**Rationale**: full control, the best frame rate, and the strongest visual match to the
references. A few hundred marks and four passes cost little on any supported iPad.

**Alternatives considered**: Core Image filters (fine for the tint, awkward for anchored coverage
at frame rate); SpriteKit or SceneKit (an extra scene graph to sync with camera frames); additive
dot sprites with strong bloom, the previous plan (looked like glowing confetti, not a coating;
rejected after seeing the references).

**Detail**: real fingernails fluoresce faintly under UV. A faint violet-white nail tint at the
fingertip joints adds realism at no cost.

---

## R7. Generating the glow pattern

**Decision**:
- **Determinism**: a seeded generator with our own small random number generator (SplitMix64),
  so the same seed always gives the same pattern on any iPadOS version (FR-006).
- **Mark kinds** (calibrated on ref-01 and ref-02):
  - **Cap**: near-solid coverage of the fingertip pad, fading toward the middle of the finger.
    One per finger and thumb, with varied extent and brightness.
  - **Streak**: elongated smudges along a finger bone, broken up by the grain.
  - **Fleck**: small grainy specks scattered over fingers and palm edges.
  - **Patch**: large, soft, low-coverage areas, mainly the heel of the hand, the little-finger
    edge of the palm, the base of the thumb, and the back of the hand.
- **Coverage targets** (measured on ref-01): about 15–25% of the visible hand at the start of the
  reveal, distributed roughly like this:

  | Part of the hand (fingertip → wrist) | Share of skin glowing |
  |---|---|
  | Top fifth (fingertips) | about 60% |
  | Second fifth | about 25% |
  | Middle fifth | about 13% |
  | Lower palm and heel | about 8–10% |

  The palm centre stays mostly clean. That matches both the references and the hand-hygiene
  literature: the centre is the part a quick wash does reach.
- **Region weights** (relative to the palm centre, used to place streaks, flecks, and patches):

  | Region | Weight |
  |---|---|
  | Fingertips and nails | 6.0 (plus the caps) |
  | Thumbs | 3.0 |
  | Between the fingers | 2.5 |
  | Back of the hand | 2.0 |
  | Wrists | 1.5 |
  | Backs of the fingers | 1.5 |
  | Palm centre | 1.0 |

  A palm-edge band (heel and little-finger edge) gets 2.0 within the palm triangles.
- **Back of the hand**: the references only show palms. The back of the hand uses the same mark
  kinds, with patches weighted toward the knuckles and between the fingers. To be reviewed in
  visual QA.
- **Left/right balance**: both hands use the same weights, and per-region coverage differs by
  at most ±10% (FR-004).
- **Fading** is a per-region multiplier over time. The rehearsal maps each WHO rubbing motion to
  the regions it reaches:

  | Step | Motion | Regions it reaches |
  |---|---|---|
  | 1 | Palm to palm | Palm centre and palm edge |
  | 2 | Palm over the back of the other hand, fingers interlaced | Back of the hand |
  | 3 | Palm to palm, fingers interlaced | Between the fingers |
  | 4 | Backs of fingers against the opposite palm | Backs of the fingers |
  | 5 | Rotational rubbing of each thumb | Thumbs |
  | 6 | Fingertips rubbed in the opposite palm | Fingertips, including the caps |

- **Quick-rinse demo**: fades only the palm centre, by about 70%. In the references that is
  exactly the area already clean, so the demo shows the "it looks washed, but…" moment honestly.
- **Wrists**: fade by 50% across the rehearsal, and the debrief mentions wrists. Confirm with the
  partner staff.

**Rationale**: the pattern looks like the references, teaches where people miss, is stable across
sessions, and is easy to test against the coverage targets.

**Alternatives considered**: random uniform marks (teaches nothing, looks unlike the
references); textures painted by hand (cannot follow finger flexion).

---

## R8. Smoothness and robustness

**Decision**:
- **Frame handling**: hand tracking always runs on the latest frame only; older frames are
  dropped.
- **Smoothing**: a One Euro filter on every joint, which damps jitter when the hand is still and
  stays responsive when it moves.
- **Display**: rendering runs at the display rate and uses the latest smoothed joints.
- **Appear/disappear**: glow fades in over about 300 ms when a hand appears, and fades out when
  it is lost.
- **Rehearsal pauses**: a step pauses after 1 second with fewer than two hands (FR-011).
- **Overload**: if frame time stays too high, the adaptive quality from R2 reduces load.

**Rationale**: meets SC-001 and the "marks stay attached" rating (SC-004) without heavy machinery.

**Alternatives considered**: a Kalman filter (more tuning); predicting motion ahead (adds risk;
revisit only if lag is visible on the oldest iPads).

---

## R9. Camera setup: hands only, never faces

**Decision**: Support two physical setups, selected in the facilitator settings. Both keep faces
out of frame by construction (Principle VII).
- **Setup A (default), overhead**: the iPad lies screen-up on a stand 30–40 cm above the table,
  with the rear camera looking down. The participant puts her hands under the iPad and looks at
  the screen from above, like a lamp hovering over her hands. This works with every iPad model.
  The stand can be bought, or built locally (the Solar Mamas are engineers).
- **Setup B, mirror clip**: the iPad stands upright facing the participant, with a clip-on mirror
  that turns the front camera down toward the table. Her posture is more natural. It depends on
  where each model's front camera sits, and the image must be flipped in software.

**Software guard**: Apple Vision face detection runs about twice per second. If a face appears,
the camera image is blanked and the session pauses until it is gone.

**Choose between A and B** during the pilot with partner staff.

**Alternatives considered**: front camera with the participant holding her hands up, which
captures her face and violates Principle VII.

---

## R10. Narration in Swahili

**Decision**: pre-recorded audio clips, read by a Swahili-speaking woman approved by Barefoot
College Zanzibar.
- A clip manifest maps clip IDs to files, the Swahili transcript, and the English source text
  (see [contracts/ui-flow.md](contracts/ui-flow.md)).
- Flow: English source script → native-speaker translation → back-translation check → partner
  review → recording.
- During development, placeholder clips are used, generated from the English script.

**Rationale**: a familiar, natural voice is more trustworthy and understandable than synthetic
speech, and the experience must not depend on reading (FR-014).

**Alternatives considered**: on-device text-to-speech (Swahili voice availability and quality
uncertain); on-screen text only (fails FR-014).

**ACTION**: Partner to nominate the voice and the reviewer.

---

## R11. Study data storage and export

**Decision**: plain local files in the app's sandbox, and no networking code in the app.
- **Files**: a participant registry (JSON) plus one append-only event log per session (JSON
  Lines). Both are written with the strongest iPadOS file protection, which requires a passcode
  on each iPad.
- **Export**: from the facilitator panel, via the iPadOS share sheet (AirDrop, Files, or a USB-C
  stick) as CSV plus JSON, following [contracts/export-format.md](contracts/export-format.md).
- **Withdrawal**: deleting a participant's data by code (FR-026).
- **During sessions**: the iPad is in Airplane Mode (privacy gate 4).

**Rationale**: about 8 participants and a few dozen sessions; a database would be complexity
with no benefit (Principle VI).

**Alternatives considered**: SwiftData or SQLite (no need at this scale); cloud sync (forbidden by
Principle II).

---

## R12. Questionnaires and measures

**Decision**: baseline and follow-up measures stay on paper, administered orally in Swahili.
- Pictorial cards show the key moments. A hand-outline card shows the six zones.
- A one-page checklist scores the handwashing demonstration.
- The researcher enters answers into a spreadsheet using the data dictionary in
  [contracts/measures.md](contracts/measures.md).
- The app only logs sessions.

**Rationale**:
- The follow-up must work without the app (FR-022), and paper keeps baseline and follow-up
  identical.
- Picture cards work for every literacy level.
- Nothing needs building (Principle VI).

**Alternatives considered**: in-app questionnaires (adds UI, and the follow-up would bring the
device back during the app-free test); online survey tools (need connectivity and reading).

---

## R13. Getting the app onto the iPads

**Decision**: Apple Developer Program plus TestFlight.
- **Install**: the facilitator installs TestFlight on each iPad and accepts the invite while the
  centre has internet.
- **Expiry**: each build stays installable for 90 days, which covers the study.
- **Kiosk mode**: during sessions, Guided Access (built into iPadOS) locks the iPad to the app.

**Rationale**: works when the owner is not physically with the iPads, and updates can be pushed
remotely.

**Alternatives considered**:
- *Ad Hoc distribution*: needs every iPad's device ID in advance.
- *Direct install from Xcode*: the owner must be present; with a free account, apps expire after
  7 days.
- *The PWA fallback (R1)*: needs no Apple account.

**ACTION**:
- Verify during the pilot that the TestFlight build launches in Airplane Mode.
- Mac and developer account confirmed (2026-11-03), so TestFlight is the distribution route.

---

## R14. Evaluation harness for SC-001 to SC-003 (gates 1 and 2)

**Decision**: a replay mode, compiled only into debug builds. It runs the full tracking and
rendering pipeline on test videos imported from Files, and writes metrics: time to first
detection, detection rate per frame, and pose-script results. Test videos:
- are recorded with consenting volunteers (team or partner staff, not study participants), using
  the iPad's built-in Camera app in the chosen setup (R9);
- cover darker skin tones, henna, rings, bangles, and the session room's lighting (SC-003);
- include a 20-pose script for the spill check (SC-002), reviewed frame by frame with an
  overlay.

**Rationale**: repeatable measurement of the gates, and regression testing whenever the look or
the tracker changes. The app itself never records camera frames (Principle II): the clips are
recorded outside it, from volunteers who agreed to it.

**Alternatives considered**: live testing only (not repeatable); public datasets (do not match
the participant group or the camera setup).

---

## R15. Language of the interfaces

**Decision**:
- **Participant**: everything in Swahili, through audio and icons; labels are secondary.
- **Facilitator**: Swahili and English.
- **Tooling**: all text in a string catalog, so translation stays a data task.

**Rationale**: FR-014, Principle VII.

---

## Open items carried into tasks

1. iPad models and iPadOS versions (R2). Owner/partner.
2. ~~Mac and Apple Developer Program~~: confirmed 2026-11-03 (R1, R13).
3. Swahili voice, translator, and reviewer nominated (R10). Partner.
4. ~~Reference glow images~~: received 2026-11-03, stored in `docs/reference/` and measured (R6, R7).
5. Physical setup A or B chosen in the pilot (R9). Owner with partner.
6. Wrist handling in the rehearsal confirmed (R7). Partner.
