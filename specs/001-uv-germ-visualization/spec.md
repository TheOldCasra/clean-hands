# Feature Specification: UV Germ Visualization Study MVP

**Feature Branch**: `001-uv-germ-visualization`

**Created**: 2026-11-03

**Status**: Clarified, ready for planning

**Input**: User description: "An app that uses the camera to show germs and bacteria on the hands, to
show users that clear doesn't mean clean. This is an MVP; the goal is to test whether this
visualization helps users remember handwashing even when the app and devices are not available.
Hand detection via foundation models if possible, otherwise a custom ML model. Germs and bacteria
look like a UV-lit surface with parts that shine (reference pictures provided by the owner)."

## Clarifications

### Session 2026-11-03

- Q: Who are the participants? → A: 8 women, aged 30+, Swahili-speaking, Muslim, in the Enriche
  life-skills program at Barefoot College International Zanzibar, who also attend the Solar
  Mamas solar-engineering training.
- Q: What is the exposure and follow-up schedule? → A: 1–2 sessions with the app, then an
  app-free period of 5 days.

## Study Design Overview

All 8 participants receive the visualization. The comparison is within each person: before the
first session versus after the 5-day app-free period. There is no comparison group (see
Assumptions for why).

| Visit | When | What happens |
|-------|------|--------------|
| Baseline | Before Session 1 (same day or up to 3 days earlier) | Consent; baseline interview; optional baseline observation window |
| Session 1 | Day 0 | Reveal (US1), rehearsal (US3), real handwash, debrief |
| Session 2 (optional) | Day 1 or 2 | Same pattern revisited, rehearsal repeated, debrief |
| App-free period | 5 days after the last session | No app, no device, no handwashing reminders |
| Follow-up | End of the app-free period | Recall and behavior interview, technique demonstration, real UV tracer demo |

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See the invisible (Priority: P1)

A participant rests her hands under the device, which looks down at them from a stand. She first
sees her hands as they normally look: clean. A Swahili voice explains that the app will now show,
as a simulation, what a special lamp can reveal. Then the "UV lamp" switches on: the scene darkens
to a deep violet, and glowing marks appear on her skin, like a fluorescent tracer under a
blacklight. Fine specks, smudges, and brighter patches gather around the fingertips and nails,
thumbs, between the fingers, the back of the hand, and the wrists. The marks stay stuck to her
hands as they move, turn, and flex. Turning a hand over shows a different pattern on the other
side. She can switch back and forth between the normal view and the UV view: this is the moment
"clear doesn't mean clean" lands. An icon with a Swahili label stays on screen to mark it as a
simulation.

**Why this priority**: This is the intervention under test. If the glow is not convincing,
stable, and memorable, nothing else matters.

**Independent Test**: Run the reveal with 3 Swahili-speaking pilot volunteers who are not in the
cohort, under the session room's lighting. Observe how fast the glow appears, whether it stays on
the hands and off the background, and ask each volunteer, using a pictorial scale, whether the
marks looked attached to her hands.

**Acceptance Scenarios**:

1. **Given** the reveal is running in the session room, **When** a hand is placed in view and
   held still, **Then** glowing marks appear on that hand within 2 seconds and do not appear
   outside the hand.
2. **Given** glow is shown on a hand, **When** the hand moves at a normal pace or the fingers
   flex, **Then** the marks follow the hand without visibly sliding off it.
3. **Given** glow is shown on the palm side, **When** the participant turns the hand over,
   **Then** the back-of-hand pattern appears, and turning back shows the same palm pattern.
4. **Given** the hand leaves the view, **When** it returns, including in Session 2, **Then** the
   same pattern reappears on it.
5. **Given** two hands are in view, **Then** both carry glow, each with its own pattern.
6. **Given** the UV view is on, **When** the participant switches to the normal view, **Then** the
   hands appear as in a normal camera image with no glow, and switching back restores the glow.
7. **Given** any glow is visible, **Then** the simulation icon and Swahili label are on screen.
8. **Given** the first reveal of a session, **Then** a spoken Swahili explanation states that the
   glow is a simulation before the glow appears.

---

### User Story 2 - Run a study session (Priority: P2)

A facilitator, a Swahili-speaking woman approved by Barefoot College Zanzibar, runs each visit.
She opens a session with a participant code (no name), confirms that consent was recorded, and
starts the flow. The system logs what happens, keeps each participant's glow pattern the same
across both sessions, and ends each session with a spoken debrief. At follow-up, the facilitator
runs the interview and demonstration without the app. Afterwards, the researcher exports a
pseudonymous dataset.

**Why this priority**: The purpose of this MVP is to answer a research question. Without
consent gating, logging, matched baseline and follow-up measures, and an app-free period, the
visualization cannot be evaluated.

**Independent Test**: Run 3 mock participants through Baseline, Session 1, Session 2, and
Follow-up in compressed time. Check that the camera never starts without recorded consent, that
every session event appears in the export, that patterns match across sessions, and that the
follow-up needs no app.

**Acceptance Scenarios**:

1. **Given** consent has not been recorded for a code, **When** anyone tries to start the
   camera, **Then** the camera does not start.
2. **Given** a participant starts Session 2, **Then** her glow pattern is the same as in Session 1.
3. **Given** a session ends or is aborted, **Then** the event log contains start, each screen and
   step reached, view switches, pauses, debrief shown, and end or abort time with reason.
4. **Given** the follow-up visit, **When** the facilitator administers it, **Then** every measure
   can be collected without the app or the study device.
5. **Given** data collection is complete, **When** the researcher exports, **Then** the export
   contains no names, contact details, voice recordings, or images.
6. **Given** the study device has no internet connection, **Then** every part of the session
   works.

---

### User Story 3 - Rehearse the wash (Priority: P3)

After the reveal, a short demonstration shows that a quick rinse of a few seconds usually reaches
only the palms: most of the glow remains elsewhere. It is presented as what typically happens,
not as a judgment of the participant. Then she rehearses the six rubbing motions of the
recommended handwashing technique under the device, without water: palm to palm, backs of the
hands, between the fingers, backs of the fingers, thumbs, fingertips. Each motion is shown by a
short demonstration and named in Swahili. As each motion is performed, the glow fades from the
areas that motion reaches. When all six are done, the hands are nearly glow-free, and she is
invited to wash with soap and water for real.

**Why this priority**: Linking the image to a concrete, practiced action is likely to strengthen
memory, and hands-on demonstration matches how Barefoot College teaches. The reveal alone can
still be tested without it.

**Independent Test**: Ask 3 pilot volunteers to follow the rehearsal. Check that each step
advances only while both hands are in view, that glow fades in the matching areas, and that the
rehearsal takes at least 20 seconds of active rubbing.

**Acceptance Scenarios**:

1. **Given** the rehearsal starts, **When** a step begins, **Then** the participant sees a
   demonstration of the motion, hears its Swahili name, and sees a progress indicator.
2. **Given** a step is in progress, **When** one or both hands leave the view for more than
   1 second, **Then** the step pauses and resumes when both hands return.
3. **Given** a step completes, **Then** glow in the areas reached by that motion has faded, and
   glow in other areas remains.
4. **Given** all six steps are completed, **Then** a spoken message invites the participant to
   wash with soap and water now.

---

### Edge Cases

- No hand, dim light, or a bright window behind the hands: spoken guidance in Swahili ("place your
  hands under the screen", "move closer to the light"), and glow is never placed on non-hand
  objects.
- Hand partly outside the frame: glow only on the visible part.
- Interlaced or overlapping hands (the "between the fingers" step): a brief detection loss does
  not reset progress; only a loss longer than 1 second pauses the step.
- Faces, clothing, or other people come into view: glow appears on hands and wrists only; the
  setup keeps faces out of frame.
- Henna patterns, rings, bangles, nail polish: detection and glow still work, and glow does not
  follow or emphasize the henna design.
- Long sleeves covering the wrists: glow only on visible skin.
- The participant becomes uncomfortable or wants to stop: an exit is available on every screen;
  the session is logged as aborted.
- The participant withdraws later: all her data is deleted by participant code.
- Camera unavailable or device battery low: clear message to the facilitator before starting.
- The device slows down or heats up: reduce visual detail rather than letting the glow lag.
- The participant asks "is this real?": the in-app explanation and the facilitator script both
  say it is a simulation of what a real UV tracer test shows; the real test is shown at
  follow-up.
- A participant misses Session 2: the follow-up still runs 5 days after her last session.

## Requirements *(mandatory)*

### Functional Requirements

**Visualization**

- **FR-001**: System MUST detect one or two hands in the live camera view and confine the glow
  effect to hand and wrist areas.
- **FR-002**: System MUST render a blacklight look: a darkened, violet-tinted scene with
  fluorescent marks (bright yellow-green to cyan, with a soft halo) on the hands. The look MUST
  be reviewed against the owner's reference images before participant use.
- **FR-003**: Glow marks MUST be anchored to the hand's anatomy, following movement, rotation,
  and finger flexion.
- **FR-004**: Glow density MUST be higher in areas commonly missed during handwashing
  (fingertips and nail areas, thumbs, between the fingers, back of the hand, wrists), with
  lighter scattered marks elsewhere. Density MUST NOT differ systematically between left and
  right hands.
- **FR-005**: Palm and back of each hand MUST have distinct patterns.
- **FR-006**: Each participant's pattern MUST be reproducible from a recorded seed and MUST be
  the same in both sessions.
- **FR-007**: Participants MUST be able to switch between the normal view and the UV view at
  any time during the reveal.
- **FR-008**: Every screen showing glow MUST display a simulation icon with a Swahili label, and
  the first reveal of each session MUST include a spoken explanation.
- **FR-009**: When no hand is detected for more than 2 seconds, System MUST give spoken and
  visual positioning and lighting guidance.

**Rehearsal**

- **FR-010**: System MUST guide the six rubbing motions of the recommended handwashing technique,
  each with a demonstration, its Swahili name, and a duration, totaling at least 20 seconds.
- **FR-011**: A step's progress MUST advance only while both hands are in view, pausing after
  more than 1 second without them.
- **FR-012**: Glow MUST fade in the areas reached by the current motion as the step progresses.
- **FR-013**: The quick-rinse demonstration MUST be presented as typical, never as an assessment
  of the participant's own washing.

**Language & accessibility**

- **FR-014**: All participant-facing content MUST be in Swahili and MUST be fully usable without
  reading (spoken narration, icons, demonstrations).
- **FR-015**: No content may suggest that ritual washing (wudu) is inadequate; soap handwashing
  at key moments MUST be framed as complementary.
- **FR-016**: Facilitator controls (start, pause, exit, next) MUST be operable without
  interrupting what the participant sees.

**Study**

- **FR-017**: The camera MUST NOT start before consent is recorded for the participant code.
- **FR-018**: Facilitators MUST be able to open a session with a participant code and without
  entering names or contact details.
- **FR-019**: System MUST support up to two sessions per participant and record which session
  is running.
- **FR-020**: System MUST log timestamped session events: start, reveal shown, view switches,
  each step reached and completed, pauses, debrief shown, end or abort with reason.
- **FR-021**: Every session MUST end with a spoken debrief explaining that the glow was
  simulated, what real UV tracer tests show, and how to wash well.
- **FR-022**: Baseline and follow-up measures MUST be identical in content and administration and
  MUST be collectable without the app. They MUST cover:
  - self-reported handwashing with soap at key moments in the past few days, using pictorial
    cards (starting set: after the toilet, before preparing food, before eating, after cleaning a
    child, after coughing or sneezing; final set agreed with partner staff);
  - a demonstration of how the participant washes her hands, scored on a checklist of the six
    motions;
  - pointing to the areas of the hand that people commonly miss.
- **FR-023**: The follow-up MUST additionally cover: whether the glow image came to mind at
  each key moment during the app-free period (cued recall), how vividly she remembers it
  (pictorial 3-point scale), whether she told anyone about it, and acceptability (anything
  uncomfortable, confusing, or inappropriate).
- **FR-024**: The follow-up MUST end with a real UV tracer demonstration (fluorescent lotion and
  a UV torch), so participants see the real effect the app imitated. Coverage after washing is
  recorded descriptively.
- **FR-025**: The protocol MUST include no handwashing reminders or app access between the last
  session and the follow-up.
- **FR-026**: Researchers MUST be able to export a pseudonymous dataset (responses, checklist
  scores, event log) and delete a participant's data by code.
- **FR-027**: System MUST NOT store or transmit camera images and MUST work without internet.

### Key Entities *(include if feature involves data)*

- **Participant**: identified only by a participant code; consent status and time; pattern seed;
  withdrawal flag.
- **Visit**: baseline, session 1, session 2, or follow-up; date; facilitator code; completion
  status.
- **Session**: an app run within a session visit; start and end times; completed or aborted,
  with reason.
- **Glow Pattern**: the simulated contamination for one participant, generated from her seed;
  per hand and side; denser in commonly missed areas; fades per rehearsal step.
- **Session Event**: a timestamped entry in a session's log (type, step, details).
- **Measure Response**: answers and checklist scores at baseline or follow-up, linked by
  participant code.

## Success Criteria *(mandatory)*

These criteria judge whether the MVP can answer the research question. Whether the glow helps is
the finding, not a pass/fail criterion. With 8 participants, results are reported per person and
descriptively.

### Measurable Outcomes

- **SC-001**: On the study devices in the session room, glow appears on a hand within 2 seconds
  of the hand entering the view in ≥95% of attempts.
- **SC-002**: In a scripted check of 20 hand poses, glow visibly spills onto the background,
  sleeves, or other objects in at most 1 pose.
- **SC-003**: Before the pilot, SC-001 and SC-002 hold on a test group of ≥10 people whose skin
  tones match the participant group, including at least 3 with henna and 3 wearing rings or
  bangles.
- **SC-004**: ≥6 of 8 participants pick one of the top two pictures on the scale for "the marks
  looked attached to my hands".
- **SC-005**: ≥7 of 8 participants complete the flow without the facilitator reading or
  translating on-screen text for them.
- **SC-006**: Each session (from start to debrief) takes 15 minutes or less.
- **SC-007**: Zero camera images are stored or transmitted, verified during the pilot.
- **SC-008**: ≥7 of 8 participants complete the follow-up.
- **SC-009**: At follow-up, ≥6 of 8 participants describe the glow image when asked what they
  remember from the sessions (check that the image was memorable).
- **SC-010**: No participant reports the content as disrespectful of her culture or religion; any
  concern raised is recorded and addressed before further use.

## Assumptions

- The glow is a simulation. The system detects hands, not microbes (constitution Principle I).
- **No comparison group.** With 8 participants, two arms of 4 cannot show a difference.
  Participants share daily program life, so they would talk about it and contaminate a control
  group, and withholding the experience from half of a small cohort would feel unfair. The study
  is therefore a single-group feasibility and acceptability pilot with within-person
  before/after measures. It can show whether the image is remembered and recalled at
  handwashing moments without the device, and the direction of any change. It cannot prove that
  the visualization caused the change; that would need a larger, controlled study.
- Barefoot College trains many women who never attended school, so literacy levels are assumed
  to vary. The experience is designed to work without reading for everyone.
- Participants already wash with water several times a day for prayer. Self-report therefore
  asks specifically about washing **with soap** at key moments; otherwise answers would hit the
  ceiling.
- Soap and water are available at the training centre. Soap access at home is asked at baseline,
  because it limits what behavior can change. Enriche's livelihood skills include soap making,
  which partner staff may want to connect to the message.
- The real UV tracer test is used only at the end of follow-up. Using it at baseline would show
  participants a real glowing reveal before the app, which would confound the app's effect.
- An optional baseline observation window (2–3 days, at a routine moment such as before the
  shared meal, by partner staff) can be added if the partner agrees; the same observation is then
  repeated during the app-free period. Observation requires consent and ethics approval.
- Sessions take place at the Barefoot College International Zanzibar centre, with the device on a
  stand looking down at the hands on a table.
- Study devices are provided by the researchers. The plan will pick the platform.
- The owner's reference images of the glow were mentioned but are not yet in the repository; they
  will be added under `docs/reference/` and used for the FR-002 review.
- Commonly missed areas follow classic hand-hygiene observations (e.g., Taylor, 1978): fingertips,
  thumbs, between the fingers, back of the hand. The six motions follow the WHO handwashing
  technique.
- Interviews are run in Swahili by the facilitator. Audio recording is optional, needs separate
  consent, and recordings stay out of the exported dataset.
- Out of scope: real germ detection, user accounts, at-home use, reminders, gesture recognition of
  each motion (progress is time-based while both hands are in view), languages other than Swahili
  for participants.
