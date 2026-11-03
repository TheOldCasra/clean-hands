# Feature Specification: UV Germ Visualization Study MVP

**Feature Branch**: `001-uv-germ-visualization`

**Created**: 2026-11-03

**Status**: Draft (awaiting clarification of 2 items)

**Input**: User description: "An app that uses the camera to show germs and bacteria on the hands, to
show users that clear doesn't mean clean. This is an MVP; the goal is to test whether this
visualization helps users remember handwashing even when the app and devices are not available.
Hand detection via foundation models if possible, otherwise a custom ML model. Germs and bacteria
look like a UV-lit surface with parts that shine (reference pictures provided by the owner)."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See the invisible (Priority: P1)

A participant holds one or both hands up to the camera. They first see their hands as they
normally look: clean. Then the "UV lamp" switches on: the scene darkens to a deep violet, and
glowing fluorescent marks appear on their skin, like a fluorescent tracer under a blacklight.
Fine specks, smudges, and brighter patches cluster around the fingertips and nails, thumbs,
between the fingers, the back of the hand, and the wrists. The marks stay stuck to the hand as it
moves, turns, and flexes. Turning the hand over reveals a different pattern on the other side.
The participant can switch back and forth between the normal view and the UV view, which is the
moment the "clear doesn't mean clean" message lands. A label makes clear this is a simulation.

**Why this priority**: This is the intervention under test. If the glow is not convincing,
stable, and memorable, nothing else matters.

**Independent Test**: Give the device to 5 people and ask them to show both sides of both hands
and switch views. Observe how fast the glow appears, whether it stays on the hands and off the
background, and ask each person to rate "the marks looked attached to my hands" (1–5).

**Acceptance Scenarios**:

1. **Given** the reveal screen is open under ordinary indoor light, **When** a hand enters the
   view and is held still, **Then** glowing marks appear on that hand within 2 seconds and do not
   appear outside the hand.
2. **Given** glow is shown on a hand, **When** the hand moves at a normal pace or the fingers
   flex, **Then** the marks follow the hand without visibly sliding off it.
3. **Given** glow is shown on the palm side, **When** the participant turns the hand over,
   **Then** the back-of-hand pattern appears, and turning back shows the same palm pattern as before.
4. **Given** the hand leaves the view, **When** it returns within the same session, **Then** the
   same pattern reappears on it.
5. **Given** two hands are in view, **Then** both carry glow, each with its own pattern.
6. **Given** the UV view is on, **When** the participant switches to the normal view, **Then** the
   hands appear as in a normal camera image with no glow, and switching back restores the glow.
7. **Given** any glow is visible, **Then** a "Simulation" indicator is visible on screen.

---

### User Story 2 - Run a study session (Priority: P2)

A researcher starts a session for a participant using a participant code (no name). The system
randomly assigns the participant to the visualization arm or the comparison arm and records it
without showing the arm label to the participant. Both arms go through the same flow, length,
and handwashing information; only the visualization arm sees the UV glow. The comparison arm
sees the live camera view of their own hands with the same steps and text but no glow. The
session ends with a debrief that explains the simulation. Questionnaires are completed before,
right after, and some days after the session; the delayed one is completed without access to
the app. The researcher can export a pseudonymous dataset.

**Why this priority**: The purpose of this MVP is to answer a research question. Without
randomization, matched arms, logging, and a delayed app-free measurement, the visualization
cannot be evaluated.

**Independent Test**: Run 6 mock sessions with team members. Check that arms are assigned
in balance, that the comparison arm never shows glow, that every session event is in the export,
and that the delayed questionnaire can be completed on any device without the app.

**Acceptance Scenarios**:

1. **Given** a researcher enters a new participant code, **When** the session starts, **Then**
   an arm is assigned at random, recorded with a timestamp, and not displayed to the participant.
2. **Given** a participant in the comparison arm, **When** they go through the flow, **Then**
   they see the same screens, text, and step durations as the visualization arm, but never any glow.
3. **Given** consent has not been recorded, **When** anyone tries to start the camera,
   **Then** the camera does not start.
4. **Given** a session ends or is aborted, **Then** the event log contains start, arm, each
   step reached, view switches, the end or abort time, and the reason if aborted.
5. **Given** the follow-up date arrives, **When** the participant completes the delayed
   questionnaire, **Then** it is linked to their code and does not require the app.
6. **Given** data collection is complete, **When** the researcher exports, **Then** the export
   contains no names, contact details, or images.

---

### User Story 3 - Rehearse the wash (Priority: P3)

After the reveal, a short demonstration shows that a quick 5-second rinse usually reaches only
the palms: most of the glow remains elsewhere. It is framed as "what typically happens", not as a
judgment of this participant. Then the participant rehearses the six rubbing motions of the
recommended handwashing technique in front of the camera, without water: palm to palm, backs of
hands, between the fingers, backs of the fingers, thumbs, fingertips. As each motion is
performed, the glow fades from the areas that motion reaches. When all six are done, the hands
are nearly glow-free, and the participant is invited to wash for real.

**Why this priority**: Linking the striking image to a concrete action is likely to strengthen
memory and make the message actionable, but the reveal alone can already be tested.

**Independent Test**: Ask 5 people to follow the rehearsal. Check that each step advances only
while both hands are in view, that glow fades in the matching areas, and that the full rehearsal
takes at least 20 seconds of active rubbing.

**Acceptance Scenarios**:

1. **Given** the rehearsal starts, **When** a step is shown, **Then** the participant sees an
   instruction for that motion and a progress indicator for its duration.
2. **Given** a step is in progress, **When** one or both hands leave the view for more than
   1 second, **Then** the step pauses and resumes when both hands return.
3. **Given** the visualization arm, **When** a step completes, **Then** glow in the areas
   reached by that motion has faded, and glow in other areas remains.
4. **Given** the comparison arm, **When** the rehearsal runs, **Then** the steps, text, and
   durations are identical, with no glow.
5. **Given** all six steps are completed, **Then** a closing message invites the participant to
   wash their hands for real now.

---

### Edge Cases

- No hand, dim light, or a strongly backlit scene: show guidance ("hold your hand up, palm toward
  the camera, in good light") and never place glow on non-hand objects.
- Hand partly outside the frame: glow only on the visible part.
- Interlaced or overlapping hands (as in the "between the fingers" step): brief detection loss
  must not reset progress; only a loss longer than 1 second pauses the step.
- Other people, faces, or other skin in view (arms, legs): glow appears on hands and wrists only,
  never on faces.
- Gloves, long sleeves, rings, watches, nail polish, tattoos: glow only on visible skin; with
  gloves, ask the participant to remove them.
- Child-size and large adult hands; the full range of skin tones; warm and cool indoor lighting:
  the glow must work equally well (see SC-003).
- The participant becomes uncomfortable or wants to stop: an exit is available on every screen;
  the session is logged as aborted.
- The participant withdraws consent later: all their data is deleted by participant code.
- Camera permission denied or camera in use: clear message, the session cannot proceed, and this
  is logged.
- The device slows down or heats up: reduce visual detail rather than letting the glow lag
  behind the hand.
- The participant asks "is this real?": the in-app answer and the researcher script both say it
  is a simulation of what a fluorescent tracer test shows.

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
  lighter scattered marks elsewhere.
- **FR-005**: Palm and back of each hand MUST have distinct patterns; a given hand's pattern MUST
  stay the same throughout a session.
- **FR-006**: Each session's pattern MUST be reproducible from a recorded seed.
- **FR-007**: Participants MUST be able to switch between the normal view and the UV view at
  any time during the reveal.
- **FR-008**: Every screen showing glow MUST display a visible "Simulation" indicator.
- **FR-009**: When no hand is detected for more than 2 seconds, System MUST show positioning
  and lighting guidance.

**Rehearsal**

- **FR-010**: System MUST guide the six rubbing motions of the recommended handwashing technique,
  each with an instruction and a duration, totaling at least 20 seconds of rubbing.
- **FR-011**: A step's progress MUST advance only while both hands are in view, pausing after
  more than 1 second without them.
- **FR-012**: In the visualization arm, glow MUST fade in the areas reached by the current
  motion as the step progresses.
- **FR-013**: The quick-rinse demonstration MUST be presented as typical, never as an assessment
  of the participant's own washing.

**Study**

- **FR-014**: The camera MUST NOT start before consent is recorded for the participant code.
- **FR-015**: Researchers MUST be able to start a session with a participant code and without
  entering names or contact details.
- **FR-016**: System MUST assign the arm by balanced randomization, record it, and keep the arm
  label hidden from the participant.
- **FR-017**: The comparison arm MUST show the same flow, text, and durations as the
  visualization arm, with the live camera view of the hands but no glow.
- **FR-018**: System MUST log timestamped session events: start, arm, reveal shown, view
  switches, each step reached and completed, pauses, debrief shown, end or abort with reason.
- **FR-019**: System MUST collect baseline, immediate post-session, and delayed follow-up
  responses linked by participant code; the follow-up MUST be completable without the app.
- **FR-020**: The questionnaires MUST cover: self-reported handwashing at key moments (after
  the toilet, before eating or handling food, after coming home, after coughing, sneezing, or
  blowing the nose); whether the session or the glow image came to mind at those moments;
  vividness of the remembered image; knowledge of the six motions and of commonly missed areas.
- **FR-021**: Every session MUST end with a debrief explaining that the glow was simulated, what
  real fluorescent tracer tests show, and how to wash well.
- **FR-022**: Researchers MUST be able to export a pseudonymous dataset (per-participant
  responses and arm, plus the event log) and delete a participant's data by code.
- **FR-023**: System MUST NOT store or transmit camera images.
- **FR-024**: Content, consent, and wording MUST suit the participant group:
  [NEEDS CLARIFICATION: Who are the participants: primary-school children, teenagers, adults,
  or a mix?]
- **FR-025**: The exposure and follow-up schedule MUST be:
  [NEEDS CLARIFICATION: One supervised session followed by an app-free follow-up after a set
  number of days, or repeated exposures over several days before an app-free period?]

### Key Entities *(include if feature involves data)*

- **Participant**: identified only by a participant code; consent status and time; age band;
  assigned arm; withdrawal flag.
- **Session**: one run of the flow for a participant; start and end times; arm; pattern seed;
  completion status (completed or aborted, with reason).
- **Study Arm**: visualization or comparison; defines whether glow is shown; everything else is
  identical.
- **Glow Pattern**: the simulated contamination for one session, generated from a seed; per hand
  and side; denser in commonly missed areas; fades per rehearsal step.
- **Session Event**: a timestamped entry in a session's log (type, step, details).
- **Questionnaire Response**: answers at baseline, post-session, or follow-up, linked by
  participant code, with completion time.

## Success Criteria *(mandatory)*

These criteria judge whether the MVP can answer the research question. The research outcome
itself (whether the glow helps) is the finding, not a pass/fail criterion.

### Measurable Outcomes

- **SC-001**: In ≥95% of attempts under typical indoor lighting on the study devices, glow
  appears on a hand within 2 seconds of the hand entering the view.
- **SC-002**: In a scripted check of 20 hand poses, glow visibly spills onto the background,
  sleeves, or face in at most 1 pose.
- **SC-003**: Across participants grouped by skin tone on a standard skin-tone scale, the rate
  of SC-001 success differs by no more than 5 percentage points between any two groups.
- **SC-004**: ≥80% of visualization-arm participants rate "the marks looked attached to my
  hands" 4 or 5 on a 5-point scale.
- **SC-005**: ≥90% of sessions (consent to debrief, excluding questionnaires) take 10 minutes
  or less.
- **SC-006**: Average session duration differs by less than 10% between the two arms.
- **SC-007**: Zero camera images are stored or transmitted, verified by inspection during the
  pilot.
- **SC-008**: ≥80% of enrolled participants complete the delayed follow-up, and the arms stay
  balanced within 2 participants.
- **SC-009**: At follow-up, ≥70% of visualization-arm participants mention the glow when asked
  what they remember from the session (check that the image was memorable).

## Assumptions

- The glow is a simulation. The system detects hands, not microbes (constitution Principle I).
- The owner's reference images of the glow were mentioned but are not yet in the repository; they
  will be added under `docs/reference/` and used for the FR-002 review.
- Sessions are supervised by a researcher, with a sink available for the real wash at the end.
- Study devices are provided by the researchers (a small number of known devices), not the
  participants' own phones. To be revisited after the FR-025 clarification.
- Two arms, randomized, as described in User Story 2. If fewer than about 64 participants per arm
  can be recruited (the usual number to detect a medium effect, d = 0.5, with 80% power at
  α = 0.05), the study is treated as a pilot that estimates effect sizes rather than a confirmatory
  test. The exact sample size is set in the study protocol.
- Default follow-up interval is 7 days, pending FR-025.
- Reminders, notifications, or any contact through the app between the session and the follow-up
  are out of scope: they would contaminate the app-free test.
- Commonly missed areas follow classic hand-hygiene observations (e.g., Taylor, 1978): fingertips,
  thumbs, between the fingers, back of the hand.
- The six motions follow the WHO handwashing technique.
- Self-report is biased; an optional objective check (real fluorescent lotion and a UV lamp at
  follow-up, scored by a rater blind to arm) can be added to the protocol if resources allow.
- One interface language for the MVP, with all copy kept separate so it can be translated.
- Out of scope: real germ detection, user accounts, at-home use (unless FR-025 says otherwise),
  gesture recognition of each rubbing motion (progress is time-based while hands are in view).
