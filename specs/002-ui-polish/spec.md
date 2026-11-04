# Feature Specification: UI Polish of the Session Flow

**Feature Branch**: `002-ui-polish`

**Created**: 2026-11-04

**Status**: Clarified

**Input**: User description: "Polish the UI of the whole flow, based on the apple-design skill
(Apple's approach to fluid, physical interfaces: response, interruptibility, springs, spatial
consistency, materials, multimodal feedback, reduced motion, typography, design foundations)."

## Clarifications

### Session 2026-11-04

- Q: When the lamp switches on, how should the glow appear? → A: It spreads from the fingertips
  toward the wrist over about 1.5 s, so the most-missed areas light first; the final pattern is
  unchanged.
- Q: How does the facilitator end a session from the strip? → A: Press and hold End for about
  1 second; a ring fills around the button; releasing early cancels. No dialog.
- Q: Should a sound play when the lamp switches on? → A: Yes, one soft, short switch click on the
  same frame the view starts to change, only at switch-on; reviewed by partner staff.

### Session 2026-11-04 (owner review of the MVP)

- Start screen: only the hands logo, the name "Clean Hands", and one large green round start
  button with a play symbol in the middle; everything else (camera setup, test tools) sits behind
  a settings gear in the top corner.
- The extra hand outline that appeared over the positioning hand after a few seconds is removed
  (the spoken guidance N02 stays).
- The facilitator strip (play/pause, next, back, replay, end) is removed. The session advances by
  itself when each voiceover ends; after the reveal narration the participant explores the lamp
  for 45 s before the session moves on. There is no pause and no reset.
- The red square Stop is replaced by an exit button with a door symbol in the top corner, on every
  screen until the session has ended (one tap, no confirmation).
- The eye and lamp buttons become one lamp button: `warninglight` when the UV view is off,
  `exclamationmark.warninglight.fill` when it is on.
- These supersede 001 FR-016 and the facilitator strip in 001's ui-flow contract.

**Builds on**: `001-uv-germ-visualization` (the reveal flow, facilitator strip, and Stop control
already built in its Setup, Foundational, and US1 phases).

## Context: what the current flow lacks

An audit of the current app against the apple-design guidance found:

- The normal → UV switch is an instant cut: the whole screen jumps from a bright camera image to
  near-black at the most important moment of the session (abrupt brightness change).
- Every state change swaps screens instantly; nothing enters or leaves along a path.
- Buttons (Stop, eye/lamp, facilitator strip) give no feedback when pressed; strip buttons are
  smaller than a comfortable touch target.
- Prompts appear before the narration that introduces them (the turn-hand icon and eye/lamp
  buttons show at once, while the first clip is still talking about something else).
- Nothing confirms to the participant that her hands were found.
- The no-hands hint pulses forever and ignores the iPad's Reduce Motion setting.
- The facilitator strip is a dimmed shape with weak legibility over the moving camera image,
  gives no sense of where the session is, and ends the session on a single accidental tap.
- No accessibility setting is honoured: Reduce Motion, Reduce Transparency, Increase Contrast,
  Larger Text.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The lamp switches on (Priority: P1)

The participant has been looking at her hands in the normal camera view. After the spoken
explanation, the "lamp" switches on: the room around her hands sinks into darkness and her skin
turns violet in one continuous, calm movement, like a real lamp being switched on, rather than a
cut. The glowing coating then appears on her skin. The simulation badge is already on screen
before the first glow appears. When she touches the eye to see her hands normally, the view
returns the same way it came; if she changes her mind halfway and touches the lamp again, the
view turns back from wherever it is, without finishing the first change.

**Why this priority**: The reveal is the intervention. An abrupt, jarring switch works against
"calm, memorable, not frightening" (constitution Principle V) at the exact moment the study
depends on.

**Independent Test**: With 3 pilot volunteers, run the reveal and record the screen. Review the
recording frame by frame: no single frame-to-frame jump in overall brightness, the badge is
visible before any glow, and a mid-change reversal continues smoothly from the current state.

**Acceptance Scenarios**:

1. **Given** the spoken explanation has finished, **When** the UV view begins, **Then** the
   background darkens and the skin turns violet gradually over a short, fixed span, with no
   frame-to-frame brightness jump, and the glow appears only after the skin has turned violet.
2. **Given** the UV view is turning on, **When** the first glow appears, **Then** the simulation
   badge is already fully visible.
3. **Given** the UV view is on, **When** the participant touches the eye, **Then** the view
   returns to normal along the same path in reverse, and the glow fades out before the skin
   returns to its normal colour.
4. **Given** a view change is in progress, **When** the participant touches the other button,
   **Then** the change reverses from its current state, with no jump and no wait.
5. **Given** Reduce Motion is on, **When** the view changes, **Then** it is a plain cross-fade
   that is shorter than the standard change.
6. **Given** a face enters the frame at any moment, including mid-change, **Then** the screen
   blanks immediately (privacy is never delayed for smoothness).
7. **Given** the skin has turned violet, **When** the glow appears, **Then** it lights the
   fingertips first and spreads toward the wrist over about 1.5 s, ending in exactly the same
   pattern as an all-at-once reveal.
8. **Given** a hand enters the view while the UV view is already on, **Then** its glow fades in
   as in 001 (the spread plays only once, at switch-on).

---

### User Story 2 - One calm motion language across the flow (Priority: P2)

Every screen of the participant flow moves and responds the same way. Touching any control shows
an immediate response on touch-down. Icons and prompts arrive together with the narration clip
that introduces them, and leave the way they came. When her hands are found, a brief confirmation
shows that the app "sees" them. Guidance hints point in the direction they ask her to move, once,
instead of pulsing forever.

**Why this priority**: Consistency makes the experience predictable for people who will not read
any text (Principle VII, Familiarity). It is the foundation that US1's screens of 001 and the
upcoming rehearsal and debrief screens reuse.

**Independent Test**: Walk the whole demo flow with Reduce Motion off and on. Check each
transition and control against the motion rules (FR-005 to FR-011) on a screen recording.

**Acceptance Scenarios**:

1. **Given** any participant control, **When** it is touched, **Then** it visibly responds on
   touch-down, and the action happens on release; dragging off the control before release cancels.
2. **Given** a state change, **When** the next screen's icons appear, **Then** they enter along
   one consistent path and leave along the same path in reverse.
3. **Given** the reveal prompts, **When** the narration reaches the "turn your hands over" clip,
   **Then** the turn-hand prompt appears at that moment; **When** it reaches the "touch the eye /
   lamp" clip, **Then** the eye and lamp buttons appear at that moment.
4. **Given** the positioning screen, **When** hands are detected, **Then** a brief confirmation is
   shown before moving on.
5. **Given** no hands for more than 2 seconds, **When** the guidance appears, **Then** it moves
   once in the direction it asks for, then rests; it repeats only when the spoken guidance
   repeats.
6. **Given** a transition is in progress, **When** the participant touches Stop, **Then** the
   session stops immediately; no animation ever blocks Stop or any other control.
7. **Given** Reduce Motion is on, **Then** every movement is replaced by a short fade, and
   nothing loops.

---

### User Story 3 - Facilitator controls that are discreet, legible, and forgiving (Priority: P3) — removed

> **Removed 2026-11-04** by the owner: there is no facilitator strip; the flow advances by itself
> and the exit button ends a session. FR-012 to FR-015 and SC-004 no longer apply. Kept below for
> the record.

The facilitator glances at the strip and sees, without reading, where the session is. The strip
stays legible over a moving camera image without drawing the participant's eye. Its buttons are
easy to hit and respond on touch-down. Ending a session by accident is hard, but does not need a
dialog that would cover the participant's view.

**Why this priority**: Facilitator errors cost a session; but the participant view comes first,
so this follows US1 and US2.

**Independent Test**: A facilitator runs 3 mock sessions using only the strip. Count mis-taps and
accidental ends; ask her where the session was at 5 random moments.

**Acceptance Scenarios**:

1. **Given** any session state, **Then** the strip shows the current step of the flow and how
   many remain, without text.
2. **Given** the camera image behind the strip changes from dark to bright, **Then** the strip's
   icons stay legible.
3. **Given** a strip button, **Then** its touch target is at least 44 × 44 points and it responds
   on touch-down.
4. **Given** the facilitator touches End, **Then** the session ends only if she holds End for about 1 second; a ring fills around the
   button while she holds, and releasing early cancels and empties the ring.
5. **Given** Reduce Transparency or Increase Contrast is on, **Then** the strip becomes solid and
   high-contrast.
6. **Given** the facilitator's text size is set larger, **Then** facilitator text grows and the
   layout still fits.

---

### User Story 4 - The lamp sounds like a lamp (Priority: P3)

When the lamp switches on, a soft switch sound plays on the same frame the view starts to change,
so sound and sight are one event.

**Why this priority**: Multimodal feedback strengthens causality and memory, but the session works
without it.

**Independent Test**: Record screen and audio; check the sound starts within one frame of the
visual change, and only at lamp switch-on.

**Acceptance Scenarios**:

1. **Given** the lamp switches on, **Then** one soft, short switch click plays, starting on the
   same frame as the visual change; switching back to normal view plays no sound.
2. **Given** a sound plays, **Then** it never overlaps the start of a narration clip.

---

### Edge Cases

- Very old iPads (A10): animations must not lower the camera view's frame rate; when the app has
  reduced visual quality (adaptive quality from 001), translucent effects fall back to solid.
- A hand disappears during the lamp switch-on: the switch continues; the glow fades out with the
  hand as in 001.
- The participant taps the eye and lamp buttons repeatedly and fast: every tap is honoured from
  the current state, without queued or stuck changes.
- A face appears mid-transition: blanking is immediate and overrides any animation.
- Narration clip missing or ends early: prompts still appear (tied to the clip starting, with a
  fallback time). The one exception is N04, the spoken explanation: without it the lamp waits for
  the facilitator (FR-004b).
- The participant touches Stop during the debrief: the session ends as stopped by the
  participant, as on any other screen.
- Stop touched during any transition: stop wins immediately.
- Facilitator presses End and releases early: nothing happens, and the progress indication
  returns to empty.
- Larger text on the facilitator side must not push the strip over the hands view.

## Requirements *(mandatory)*

### Functional Requirements

**Lamp switch (US1)**

- **FR-001**: The change between normal view and UV view MUST be a continuous transition of fixed
  short length (target 0.6–1.0 s), not a cut, with no frame-to-frame jump in overall brightness.
- **FR-002**: During switch-on, the background MUST darken and the skin turn violet before any glow
  appears; during switch-off, the glow MUST fade out before the skin returns to normal.
- **FR-003**: The simulation badge MUST be fully visible before the first glow appears and stay
  visible until the last glow has faded or has been fully covered by a calm screen; while a calm
  screen fades in, the badge is covered together with the glow, never before it (001 FR-008,
  constitution Principle I).
- **FR-004**: A view change MUST be reversible at any moment, continuing from the current state
  without a jump.
- **FR-024**: Leaving the camera view for a calm screen (debrief, end, or stop) MUST NOT jump in
  brightness (same limit as SC-001); the session itself ends at once, and only the picture fades.
  Face-guard blanking is exempt (FR-020).
- **FR-004b**: The lamp MUST NOT switch on for the first time in a session unless the spoken
  explanation (N04) has played to its end. If N04 is missing or fails to play, the flow MUST wait
  on the lamp screen until the facilitator has given the explanation in person and continues. A
  session MUST NOT start while any narration clip is missing (constitution Principle I).
- **FR-004a**: At the first switch-on of a session, the glow MUST spread from the fingertips toward
  the wrist over about 1.5 s; afterwards (view toggles, hands re-entering) it fades in as in 001.
  The spread MUST NOT change the final pattern. With Reduce Motion on, the glow fades in at once.

**Motion language (US2)**

- **FR-005**: All participant-facing motion MUST use one shared set of motion values, with no
  overshoot or bounce (nothing in this flow is thrown or flicked).
- **FR-006**: Every control MUST respond visibly on touch-down within one frame and act on
  release; moving off the control before release MUST cancel.
- **FR-007**: No transition may block input. The exit button (door symbol, top corner) MUST be
  visible and working on every screen from session start until the session has ended, including
  the debrief and every calm screen before the end.
- **FR-008**: Elements MUST enter and leave along the same path; prompts that point somewhere
  (arrow, turn-hand) MUST move in that direction.
- **FR-009**: The turn-hand prompt and the eye/lamp buttons MUST appear when their narration clip
  starts (N06 and N07), with a fallback if a clip is missing.
- **FR-010**: Hand detection on the positioning screen MUST be confirmed visually before the flow
  moves on.
- **FR-011**: No hint may loop continuously; guidance moves once per spoken prompt.

**Facilitator strip (US3)**

- **FR-012**: The strip MUST show the current step and the steps remaining, using shapes only.
- **FR-013**: The strip MUST stay legible over both dark and bright camera images while staying
  less prominent than the participant's content.
- **FR-014**: Strip touch targets MUST be at least 44 × 44 points.
- **FR-015**: Ending a session from the strip MUST require holding End for about 1 second with a
  filling ring as progress; releasing early cancels. It MUST NOT show anything over the
  participant's view.

**Lamp sound (US4)**

- **FR-016**: The lamp switch-on sound MUST be a single soft, short click that starts on the same
  frame as the visual change, plays only at switch-on (not on switch-off), and MUST NOT overlap the
  start of a narration clip. It works offline and contains no speech.

**Accessibility (all stories)**

- **FR-017**: With Reduce Motion on, all movement MUST become short cross-fades, and no element may
  loop.
- **FR-018**: With Reduce Transparency or Increase Contrast on, translucent surfaces MUST become
  solid with a contrasting edge.
- **FR-019**: Facilitator text MUST follow the iPad's text size setting without breaking layout;
  participant screens stay icon-first and need no text.
- **FR-020**: Privacy blanking (face guard) MUST stay immediate and is exempt from every
  transition rule.

**Performance and study integrity**

- **FR-021**: Polish MUST NOT reduce the camera view's frame rate below 001's targets (60 fps on
  A12+, 30 fps on A10); translucent effects fall back to solid at reduced quality levels.
- **FR-022**: Shared motion values, button behaviour, and surface styles MUST be reusable, so the
  remaining 001 screens (registration, rehearsal, quick-rinse demo, real-wash prompt, debrief)
  adopt them without new design work.
- **FR-023**: The polished flow MUST be frozen (same app version) before the first `ZNZ` session,
  so every participant sees the same experience (Principle III).
- **FR-025**: Every study iPad MUST use one fixed accessibility profile during sessions (Reduce
  Motion, Reduce Transparency, and Increase Contrast off; default text size). The app MUST read
  these settings and the iPadOS version at session start, warn the facilitator if they differ from
  the profile, and record them with the session. Any deliberate deviation for a participant who
  needs it is recorded, not hidden.
- **FR-026**: The simulation badge MUST look the same on every study iPad and at every quality
  level (a solid chip), because it is the Principle I indicator.

### Key Entities

- **Motion style**: the shared motion values (standard, quick, lamp switch) and their reduced-motion
  equivalents.
- **Surface style**: the shared translucent surface (strip, badge) and its solid fallback.
- **Flow step**: a position in the session flow shown by the facilitator strip.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In frame-by-frame review of the reveal, no consecutive frames differ in average
  screen brightness by more than 10% of the full range during a view change.
- **SC-002**: In 100% of reviewed reveals, the simulation badge is visible in the frame where glow
  first appears.
- **SC-003**: Every control shows feedback in the first frame after touch-down (screen recording).
- **SC-004**: In 3 mock sessions, the facilitator has zero accidental session ends and names the
  current step correctly at least 4 times out of 5.
- **SC-005**: With Reduce Motion on, a full walkthrough shows no movement other than fades and no
  looping element.
- **SC-006**: Render rate during transitions stays at or above 001's targets on the oldest study
  iPad.
- **SC-007**: At least 2 of 3 pilot volunteers describe the lamp switch-on as calm or pleasant, and
  none as startling (pictorial or spoken answer, recorded descriptively).
- **SC-008**: Partner staff sign off on any new visual or sound elements (the confirmation,
  step indicator, and any lamp sound) as culturally appropriate (Principle VII).

## Assumptions

- The apple-design guidance is written for the web; it is applied here to the native iPad app with
  the platform's own equivalents (system springs, materials, accessibility settings).
- Participant screens remain icon-first and Swahili-voiced; this feature adds no participant-facing
  text.
- iPads have no haptic engine, so multimodal feedback is visual and audio only.
- Accessibility settings are supported (FR-017 to FR-019) so the app behaves well on any iPad,
  but study sessions run with one fixed profile (FR-025) so every participant sees the same
  intervention (Principle III).
- The glow look itself (pattern, colour, coverage) is unchanged; only how it arrives and leaves.
- Debug and QA tools (demo launcher, replay harness, tuning panel) are polished only where shared
  components apply; they are not participant-facing.
- Screens not built yet in 001 (registration, rehearsal, debrief, export) are out of scope here,
  but must adopt the shared styles from this feature when they are built (FR-022).
