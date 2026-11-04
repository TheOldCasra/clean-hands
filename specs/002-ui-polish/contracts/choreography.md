# Contract: Choreography of the Participant Flow

What moves, when, along which path, and what the narration is saying at that moment, for every
participant state. Covers US1 (lamp switch), US2 (motion language), FR-001..FR-011, FR-016,
FR-017, FR-020. States follow [001 data-model](../../001-uv-germ-visualization/data-model.md);
clips follow [001 ui-flow](../../001-uv-germ-visualization/contracts/ui-flow.md). This is a
contract, not code: names below are the canonical ones other 002 contracts use.

## 1. Ground rules

| # | Rule | Source |
|---|---|---|
| C1 | One path per element: what enters leaves by the exact reverse of its entry, from its current presentation value. | FR-008, skill §7 |
| C2 | Two triggers only: **state entry**, or a **cue** = a narration clip starting (`NarrationPlayer.currentClip` becomes that id). Every cue has a fixed-delay **fallback** from state entry. | FR-009 |
| C3 | Cues are latched in the model for the current state visit (not in view state), so a coalesced UI update, a pause, or a missing clip cannot lose them. A missing clip still emits its start (as `onClipPlayed` does today) and advances at once. | Edge cases |
| C4 | No animation gates input or a state change. Stop and every control act on release at any moment; a new target always starts from the on-screen value. | FR-004, FR-006, FR-007 |
| C5 | Hints (arrow nudge, turn-hand flip, outline nudge) move **once per cue**, then rest. Nothing loops, ever. | FR-011, FR-017 |
| C6 | Whole-screen brightness changes (lamp, camera ↔ calm surface, un-blank) use the 0.8 s `Motion.lamp` curve. Exceptions: face-guard blank (instant) and Stop (`Motion.standard`). | FR-001, skill §14 |
| C7 | `LampClick` fires on the same frame `uvAmount` starts rising, at every switch-on, never at switch-off. No clip may **start** within 0.8 s after a click; a clip requested in that window is deferred to its end. | FR-016, skill §13 |
| C8 | Restore, never replay: leaving a pause re-shows the latched state without `LampClick`, glow sweep, entrance motion, or hint motion. Pauses freeze `uvAmount`, `glowReveal`, and cue fallback timers at their current values. | FR-020 |
| C9 | No overshoot anywhere; every spring is critically damped. | FR-005 |

## 2. Tokens and paths

| Token | Value | Used for |
|---|---|---|
| `Motion.standard` | spring, response 0.35 s, no bounce | element entry/exit, hint motion, Stop overlay |
| `Motion.quick` | 0.2 s | press feedback, selection highlight, badge opacity, small exits |
| `Motion.lamp` | 0.8 s, renderer-driven (integrator: lamp-transition §2) | `uvAmount` 0⇄1; its curve is reused for C6 cross-fades |
| `Motion.glowSpread` | 1.5 s | `glowReveal` 0→1 fingertip→wrist, first switch-on of a session only |
| `Motion.reducedFade` | 0.2 s opacity | every movement when Reduce Motion is on, except the lamp switch, which uses `Motion.lamp`'s reduced 0.4 s linear cross-fade (motion-and-surfaces §1, lamp-transition §4) |

- **`promptTransition`** (the one participant path): opacity 0→1 and scale 0.92→1 about the
  element's own centre, **in place, no translation**; removal is the exact reverse. Token
  `Motion.standard`. Reduce Motion: opacity only, `Motion.reducedFade`. Because entries never
  translate, the only directional movement on screen is a hint, so hints are unambiguous.
- **`PressableStyle`**: touch-down → scale 0.96 and brighten within one frame (`Motion.quick`);
  action on release inside the target (system drag-off distance); drag-off cancels and springs back.
  Reduce Motion: brighten only. Applies to Stop, eye, lamp, and strip buttons.
- **Hint emphasis** (Reduce Motion substitute for any hint): opacity 0.85 → 1.0 → 0.85, each
  leg `Motion.reducedFade`, once per cue. No position, scale, or rotation change.
- **Persistent elements**: Stop (bottom-trailing) materializes with `promptTransition` when the
  session starts (consentCheck) and never moves. It stays above every participant layer, calm
  surfaces included, and works on every screen until `ended` (FR-007); it leaves only when the
  session has ended. The `SimulationBadge` on
  `GlassSurface` has one fixed anchor (top-leading, clear of the strip) and never moves; see §4.
  The facilitator strip (`StepIndicator`, `HoldToEndButton`) is above every participant layer
  and is never covered or animated by participant choreography; `StepIndicator` advances with
  `Motion.standard` on state entry; the `HoldToEndButton` ring fills linearly over 1.0 s while
  held and empties with `Motion.standard` on early release.

## 3. Orientation and direction

**Assumption**: in setup A (iPad flat, screen up, hands beneath it) the participant sits at the
UI's **bottom edge** and looks down at the screen; the facilitator strip sits at the **top
edge** (furthest from her). The camera image shows her hands as she would see them from above:
wrists toward the bottom edge, fingertips toward the top. Setup B (upright, facing her) has the
same edges, so every rule below holds for both setups.

Consequence: in setup A, screen-down means "toward her body", not "beneath the screen". A
downward hint must therefore end **on a target**, never point at her edge.

| Element | Direction rule | Motion (once per cue) | Reduce Motion |
|---|---|---|---|
| Positioning arrow | Sits just above the hand outline, pointing at it; nudges toward the outline (screen-down) and stops short of it. Reads "into this spot" in A, literally "down to the table" in B. | Down 16 pt, back to rest, `Motion.standard` each leg; at N01 start and each N02 start | Hint emphasis |
| No-hand outline (other camera states) | Same downward nudge onto its own resting place. | Down 12 pt and back, per N02 start | Hint emphasis |
| Turn-hand prompt | A hand glyph (replaces 001's circular arrows, which say "spin", not "turn over"). Flips 180° about the screen's vertical axis, which is her forearm axis in both setups; thumb edge lifts toward the viewer first, as a right hand turns palm-up → palm-down. Rests on the mirrored side; a replayed N06 flips it back. | One 180° turn, `Motion.standard` | Cross-fade glyph → mirrored glyph, `Motion.reducedFade` |
| `HandsFoundConfirmation` | No direction: confirms, does not guide. | §4 | Opacity only |
| Glow sweep | Anatomical, per hand, fingertips → wrist along the finger axis; never mapped to screen axes. In setup A it reads top → bottom, toward her. | `Motion.glowSpread`, once per session | Glow fades in at once (`Motion.reducedFade`) |

## 4. State-by-state choreography

"Reverse" = the exact reverse of that element's entry (C1). Clip column: the clip that starts
at state entry unless marked as a cue.

| State | Enters (where / how) | Token | Trigger | Leaves (path) | Clip | Reduce Motion |
|---|---|---|---|---|---|---|
| idle (facilitator) | Start content, in place | `Motion.standard` | entry | reverse | — | opacity |
| consentCheck / blocked (facilitator, US2) | Solid panel, in place (the camera is off; glass is reserved for small chrome, motion-and-surfaces §3) | `Motion.standard` | entry | reverse | — | opacity |
| deviceReady | Black. After 1 s still starting: a static camera glyph; camera error text on a solid panel (facilitator) | `Motion.standard` | entry + 1 s | reverse, under the camera fade-up | — | opacity; never a spinner (it loops) |
| positioning | Camera image fades up from black (C6). Hand outline (centre) and arrow above it via `promptTransition` | `Motion.standard`; fade-up `Motion.lamp` curve | entry; arrow nudge at N01 cue (after entry settles) and each N02 cue | arrow: reverse, `Motion.quick`, when confirmation starts; outline: see next row | N01; N02 (cue, no hands > 2 s) | opacity; hint emphasis |
| `HandsFoundConfirmation` (positioning; reused by paused(step)) | Hands seen continuously 0.5 s → t=0: outline glyph cross-fades to its filled glyph, white at 0.95 (never glow green or lamp violet, which mean "hidden things" and "lamp"); arrow leaves. t=0.2: filled. t=0.5: state advances. No sound: N03 is the audible confirmation. | `Motion.quick` fill; `Motion.standard` exit | stability met | filled outline leaves by reverse `promptTransition` while N03 starts | — | identical (already opacity only) |
| normalView | Nothing new; camera continues | — | entry | — | N03 (from positioning) | — |
| no-hand guidance (camera states except positioning, rehearsal) | Hand outline, centre, via `promptTransition` | `Motion.standard` | `showNoHandGuidance` true; nudge per N02 cue | reverse as soon as a hand is seen; no confirmation | N02 (cue) | opacity; hint emphasis |
| uvIntro | Lamp icon, centre, via `promptTransition`. Badge materializes at its anchor (opacity `Motion.quick`, scale `Motion.standard`): fully opaque by entry + 0.2 s | `Motion.standard` | entry = N04 start | lamp icon: reverse on the uvReveal entry frame, alongside the switch; badge stays (leaves only on Back to normalView, or under a calm surface) | N04 | opacity |
| uvReveal (first visit) | Lamp switch, glow sweep, turn-hand at N06, eye/lamp at N07: **§5** | §5 | entry, cues | turn-hand: reverse at N07 cue; eye/lamp stay | N05 → N06 → N07 (delayed per C7) | §5 |
| uvReveal (lamp tapped, from normalView2) | `LampClick` + `uvAmount` → 1 from its current value; glow returns through the glow gate inside the same change (lamp-transition §3); lamp button takes the selected look | `Motion.lamp`; highlight `Motion.quick` | tap release | — | none | 0.4 s linear cross-fade, then glow over 0.2 s (lamp-transition §4) |
| normalView2 (eye tapped) | One change: `uvAmount` → 0 from its current value; the glow gate closes first, so glow is gone before the skin changes (lamp-transition §3); no sound; eye takes the selected look; badge and buttons stay | `Motion.lamp` (whole change) | tap release | — | none | 0.4 s linear cross-fade |
| paused(faceGuard) | Black + hand icon on the detection frame; every prompt and the badge hidden that frame; Stop and strip stay. **Exempt from all rules** (FR-020) | none | face detected | when face gone: blank fades out over the restored view (C6, 0.8 s), restore not replay (C8) | N21 | same |
| paused(facilitator) | Pause glyph, centre, via `promptTransition`; arrow, outlines, turn-hand, eye/lamp leave (reverse, `Motion.quick`) because they would not act; badge stays (glow can stay visible); camera live | `Motion.standard` | entry | pause glyph reverse; prompts re-enter in place, no hint (C8) | narration stops | opacity |
| debrief | Calm surface (§7); then lamp icon via `promptTransition`; hands icon at N19 cue time (manifest cue, default half the clip; fallback entry + 8 s) | `Motion.lamp` curve; icons `Motion.standard` | entry; cue time | icons reverse when ended(completed) enters | N19 | surface unchanged; icons opacity |
| ended(completed) | Surface unchanged (no brightness change); debrief icons leave while heart enters, in place | `Motion.standard` | entry | heart reverse when facilitator returns to idle | — | opacity |
| ended(aborted) | Calm surface over everything (§6). If reveal was reached: lamp and hands icons while N19 plays, then heart at N20 cue; otherwise heart at entry | `Motion.standard`; icons `Motion.standard` | entry; N20 cue | as above | N19 → N20, or N20 | opacity |

**Future 001 states** (placeholders: their screens MUST follow these rows when built, FR-022):

| State | Enters | Token | Trigger | Leaves | Clip | Reduce Motion |
|---|---|---|---|---|---|---|
| quickRinseDemo | Eye/lamp leave (reverse). If the lamp is off, it switches on (C7: `LampClick`, N08 deferred 0.8 s). Palm-centre fade (renderer, `FadeState`) starts at the N08 cue | `Motion.quick`; `Motion.lamp` | entry; N08 cue | — | N08 | lamp cross-fade; region fade unchanged (it is not movement) |
| rehearsal intro / rehearsal(n) | Demo panel (solid) via `promptTransition` at N09 cue; each step's demo replaces the previous in place (cross-fade) at its cue N10..N15; region fades run over the step seconds | `Motion.standard` | N09..N15 cues | panel reverse at N17 cue | N09..N15 | demo plays once per cue and rests on its final frame |
| paused(step n) | Two-hands icon via `promptTransition`; one downward nudge per N16 cue (§3); demo and region fades freeze (C8) | `Motion.standard` | entry = N16 | both hands back → `HandsFoundConfirmation` (≤ 0.5 s), then rehearsal(n) resumes, no replay | N16 | opacity; hint emphasis |
| realWashPrompt | Soap-and-water icon via `promptTransition`. If the lamp switches off here: switch-off rule, no click | `Motion.standard`; `Motion.lamp` | N18 cue | reverse on debrief entry | N18 | opacity |

The rehearsal demo is instruction content, not a hint: with Reduce Motion off it may repeat
**only while its step is active**, never across a pause, never as a hint (FR-011).

## 5. Reveal timeline: N04 start → N07 end

T0 = uvIntro entry = N04 start. t0 = N04 end = uvReveal entry. D5, D6, D7 = clip durations
(each ≤ 12 s; N04 ≤ 25 s).

| Time | What happens | Trigger | Reduce Motion |
|---|---|---|---|
| T0 | Lamp icon enters (centre); badge materializes at its anchor; camera stays normal | entry, N04 starts | opacity only |
| T0 + 0.2 s | **Badge fully opaque.** It stays until the camera leaves for a calm surface. | — | same |
| t0 | Same frame: `LampClick` plays, `uvAmount` starts 0 → 1 (background darkens, skin turns violet); lamp icon leaves (reverse). Glow pixels: none. | N04 completion → state entry | `uvAmount` 0.4 s linear cross-fade (lamp-transition §4); click unchanged |
| t0 + 0.8 s | `uvAmount` = 1. `glowReveal` 0 → 1 begins (fingertips first). N05 starts (deferred by C7), so "Look: …" lands on the first glow. | `uvAmount` = 1 and badge opaque (gate G1) | at t0 + 0.4 s the whole pattern fades in over 0.2 s (no spread); N05 still at t0 + 0.8 s |
| t0 + 2.3 s | `glowReveal` = 1: final pattern, identical to an all-at-once reveal | — | (done at t0 + 0.6 s) |
| t0 + 0.8 + D5 | Turn-hand prompt enters, then flips once (§3) | N06 cue, not before t0 + 2.3 s (G2) | opacity; glyph cross-fade |
| t0 + 0.8 + D5 + D6 | Turn-hand leaves (reverse); eye and lamp buttons enter together, bottom centre, lamp selected | N07 cue | opacity |
| … + D7 | N07 ends. Nothing moves until a tap, a cue, or the facilitator. | — | — |

**Gates**: G1 — `glowReveal` may not start before `uvAmount` = 1 **and** badge opacity = 1
(FR-002, FR-003). G2 — no reveal prompt before the sweep ends. G3 — the lamp switches on only
after N04 has played to its end **and** uvIntro has lasted ≥ 1.0 s (FR-004b). Never on a timer
alone.

**Fallbacks** (measured in unpaused time from t0; a fallback never fires once its cue latched;
a cue arriving after its fallback replays only the hint motion, never the entrance):

| Missing / failed | Result |
|---|---|
| N04 missing or fails | No switch. uvIntro waits; the facilitator gives the scripted explanation in person and taps Next, which starts t0. Sessions cannot start with a missing clip (FR-004b), so this is a last-resort path |
| N05 missing | N06 starts at t0 + 0.8 s; turn-hand still waits for G2 (t0 + 2.3 s) |
| N06 never starts | Turn-hand enters at t0 + 14 s (= 0.8 s lamp + 12 s max N05 + 1.2 s margin) |
| N07 never starts | Eye/lamp enter at t0 + 26 s (14 s + 12 s max N06) |
| Chain stopped (pause, face guard) before a cue | On resume, every prompt not yet shown enters at once (no clip will introduce it); the facilitator may Replay |
| Facilitator Replay of N06 / N07 / N01 / N02 | Hint motion plays once; nothing re-enters |

## 6. Interruptions

| Event | During | Required behaviour |
|---|---|---|
| Stop (release) or `HoldToEndButton` complete | any transition, sweep, confirmation, calm fade | On the release frame: state → ended(aborted), capture and tracking stop, pending cues/fallbacks/completions cancelled, narration switches. The calm surface enters over the held last frame with the 0.8 s `Motion.lamp` curve (§7); the badge stays mounted under it, so glow and badge are covered together and the badge outlives the glow (FR-003). Nothing waits for an in-flight animation. |
| Face detected | anything, including mid-lamp, mid-sweep, mid-confirmation | Blank on the detection frame, no transition (FR-020). `uvAmount`, `glowReveal`, and fallback timers freeze. A face during the un-blank fade blanks again instantly. |
| Facilitator pause | mid-lamp or mid-sweep | Freeze at current values; resume continues from them for the remaining duration; no second click (C8). |
| Eye/lamp tapped mid-change, or repeated fast taps | lamp switching | State changes at once (no queue); renderer re-targets `uvAmount` from its current value. Glow stays gated: reversing before glow began means no glow appears; glow returns through the glow gate inside the change (lamp-transition §3). `LampClick` on each change of target to UV, at most one per 0.2 s. |
| Eye tapped during the first sweep (only reachable via fallback edge cases) | `glowReveal` < 1 | Sweep counts as played; the glow gate closes before the skin changes (lamp-transition §3); later switch-ons return through the gate, with no spread (FR-004a). |
| Hand leaves during the sweep | `glowReveal` < 1 | Lamp and sweep continue on their own clocks. That hand's glow fades with 001 presence; if it returns before t0 + 2.3 s it shows the current sweep front; after, the 001 fade-in (US1 #8). Prompts are not delayed. |
| Hand leaves during `HandsFoundConfirmation` | t = 0…0.5 s | Confirmation completes and advances; normalView's no-hand guidance takes over after 2 s. |
| Facilitator Next / Back | any transition | New state's choreography starts from current presentation values (e.g. Next mid-switch → calm fade over the half-switched frame). Back stops the current clip so speech and screen agree. |

## 7. Calm screens (debrief, ended)

- **One path**: the calm surface always arrives as a full-screen opacity cross-fade in place,
  never a slide; it is solid (calm colour of 001, no `GlassSurface`, unaffected by Reduce
  Transparency). Layer order: camera < prompts < badge < calm surface < Stop < strip. The badge
  and the held camera frame stay mounted until the surface is opaque, so they are covered
  together (FR-003).
- **No brightness jump** (FR-024): on entry, capture stops and the renderer stops presenting, so
  the view keeps its last displayed frame (display only, never stored, Principle II) while the
  surface fades in over it with the 0.8 s `Motion.lamp` curve (C6). The lamp is not snapped and
  `blank` is not set until the surface is opaque. From a bright normal view this keeps each frame's luma change
  under 10 %. The held frame is released when the surface is opaque.
- **Stop / End** use the same 0.8 s curve: every whole-screen brightness change lasts ≥ 0.6 s
  (motion-and-surfaces §1). The session has already ended on the release frame; only the
  picture fades.
- Icons enter only after the surface is opaque, via `promptTransition`; icon swaps between
  debrief and ended happen in place with no surface change.
- Face guard is the only path to black without a fade; it never leads into a calm screen
  directly (an abort from face guard starts from black, so no brightness change occurs).
- Reduce Motion: the surface cross-fade is kept (it is a fade, not movement); icons fade only.

## 8. Review checklist (slow-motion screen recording)

Record at 60 fps with audio, on the oldest study iPad (A10) and one A12+, Reduce Motion off and
on. Review frame by frame; luma = per-frame mean (e.g. `ffmpeg signalstats` YAVG).

- [ ] **SC-001** Lamp on, lamp off, mid-change reversal, calm entry, Stop overlay, un-blank: no
  consecutive-frame luma difference > 10 % of range (25 on 0–255). Face-guard blank frame excluded.
- [ ] **SC-002** In the first frame with any glow pixel, the badge is fully opaque; it has been
  opaque ≥ 0.8 s (48 frames). Repeat for every toggle back to UV.
- [ ] FR-002: first glow frame is ≥ 48 frames after the first lamp frame on the first reveal, and ≥ 36 frames (60 fps) on toggles back to UV; on switch-off, the last
  glow frame precedes the first frame where the skin is no longer fully violet (lamp-transition L3).
- [ ] FR-007/C1: Stop is visible on every screen from consentCheck to ended, debrief included;
  Stop during N19 ends the session as aborted/participantStopped.
- [ ] FR-004b: with N04 removed from the bundle, the session cannot start; with N04 failing at
  run time, the lamp waits for the facilitator's Next.
- [ ] FR-016: `LampClick` onset within 1 frame of the first changed lamp frame; no click on
  switch-off; N05 onset ≥ 0.8 s after the click.
- [ ] FR-004a: fingertips glow before the wrist; final sweep frame matches a no-sweep reveal of
  the same seed and pose (replay harness). Second switch-on fades, no sweep.
- [ ] FR-009: turn-hand first visible ≤ 2 frames after N06 onset and not before sweep end;
  eye/lamp ≤ 2 frames after N07 onset. With N06/N07 removed, fallbacks fire at t0 + 14 s / 26 s.
- [ ] FR-010: filled outline visible before N03 onset; ≤ 0.5 s from fill start to normalView.
- [ ] FR-008/C1: for each element, the exit frames are the entry frames reversed.
- [ ] FR-011/C5: arrow nudges exactly once per N01/N02 onset; turn-hand flips once per N06 onset;
  a 30 s still period on each screen shows no movement.
- [ ] FR-006: every control's first frame after touch-down differs (SC-003); drag-off cancels.
- [ ] FR-007: Stop mid-lamp, mid-sweep, mid-confirmation: calm overlay starts on the release frame.
- [ ] FR-020: blank is the first frame after detection; no fade frames; resume plays no click,
  sweep, or entrance.
- [ ] **SC-005** (Reduce Motion on, full walkthrough): no frame shows translation, scale, or
  rotation of any element; only opacity changes; glow arrives all at once; nothing repeats.
