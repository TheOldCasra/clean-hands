# Contract: UI Flow, Facilitator Controls, and Narration

The interface contract between the app and its two users: the participant, who sees and hears
only Swahili, and the facilitator. The states follow [data-model.md](../data-model.md).

## Participant-facing rules

- No screen requires reading. Every instruction is spoken (narration clip) and shown with an
  icon or demonstration. Swahili labels are secondary (FR-014).
- A large **Stop** control (a red square icon, not a hand) is visible on every screen. Tapping it
  ends the session as `aborted / participantStopped`, with no confirmation dialog.
- While glow is visible, a simulation label (the Swahili word for "simulation", a small quiet
  text label since 002's owner review, constitution v2.0.1) is always on screen (FR-008).
- No shaming or disgust language or imagery (Principle V). Wording is always about "most people",
  never "you" (FR-013).

## Facilitator controls (FR-016)

- **Discreet strip**: a semi-transparent strip on the screen edge furthest from the participant,
  with Next, Back, Pause, Replay narration, and End. It never covers the hands view.
- **Settings panel**: opened by a two-finger long press (2 s) on the strip. It holds
  participant registration and consent, camera setup (A/B), Device Check, export, and withdrawal.
  The panel blanks the camera view while open.
- **Kiosk mode**: during sessions, Guided Access locks the iPad to the app.

## Screens and narration

The English source text is below. The Swahili transcript and audio are produced per research
R10. The clip ID format is `Nxx` (matches `narrationPlayed.clipId`).

| State | What the participant sees | Clip | English source (to be translated) |
|---|---|---|---|
| positioning | Live camera, hand-outline icon, arrow | N01 | "Please place your hands under the screen, with your palms facing up." |
| positioning (no hands for >2 s) | Same, with a pulsing outline | N02 | "Bring your hands a little closer, into the light." |
| normalView | Live camera, normal colors | N03 | "These are your hands. They look clean, don't they?" |
| uvIntro | Lamp icon, simulation badge | N04 | "Now we will switch on a special lamp. This is a picture made by the tablet, not a real test. It shows what a real lamp can reveal on most people's hands: things our eyes cannot see." |
| uvReveal | Violet scene, glowing marks | N05 | "Look: under this lamp, the hidden things shine. They gather at the fingertips, thumbs, between the fingers and on the back of the hand." |
| uvReveal (prompt) | Turn-hand icon | N06 | "Turn your hands over and look at the other side." |
| uvReveal (prompt) | One light button (off: `warninglight`, on: `exclamationmark.warninglight.fill`) | N07 | "Touch the light button to switch the special lamp off, and touch it again to switch it on. Clear is not always clean." |
| quickRinseDemo | Palm-center glow fades | N08 | "When most people wash quickly, only the middle of the hand gets clean. The rest stays." |
| rehearsal intro | Demonstration loop | N09 | "Let's practice the six movements that clean the whole hand. Rub your hands together, without water, as you see." |
| rehearsal step 1 | Demo: palm to palm | N10 | "Palm to palm." |
| rehearsal step 2 | Demo: palm over back, fingers interlaced | N11 | "One palm over the back of the other hand, then change." |
| rehearsal step 3 | Demo: fingers interlaced | N12 | "Palm to palm with fingers crossed." |
| rehearsal step 4 | Demo: backs of fingers | N13 | "The backs of the fingers in the other palm." |
| rehearsal step 5 | Demo: thumb rotation | N14 | "Hold each thumb and turn it." |
| rehearsal step 6 | Demo: fingertips in palm | N15 | "Rub the fingertips in the other palm." |
| rehearsal paused | Two-hands icon | N16 | "Keep both hands under the screen." |
| rehearsal done | Nearly glow-free hands | N17 | "Well done. With these six movements, the whole hand gets clean." |
| realWashPrompt | Soap-and-water icon | N18 | "Now let's wash with soap and water, the same way. Soap and water at the important moments help protect you and your family, together with the washing you already do every day." |
| debrief | Lamp icon, then the hands icon | N19 | "Remember: the glowing marks today were a picture made by the tablet. A real special lamp shows the same thing. Germs hide where we do not see them, and washing with soap, using the six movements, removes them. Thank you." |
| aborted | Calm screen; camera off at once | N19 then N20 if the session reached uvIntro (FR-021), otherwise N20 | "Thank you. We can stop here." |
| face guard | Blank screen, hands icon | N21 | "Only the hands, please. Let's move the tablet a little." |

Narration constraints:
- Each clip is ≤ 12 s, except N04 and N19 (≤ 25 s).
- The voice is a woman approved by the partner.
- Clips are triggered by state entry. The facilitator can replay any clip.

## Rehearsal timing

| Step | Active seconds (default) | Fades region (research R7) |
|---|---|---|
| 1 | 4 | palm, palmEdge |
| 2 | 5 (2.5 per side) | backOfHand |
| 3 | 4 | interdigital |
| 4 | 4 | dorsalFinger |
| 5 | 4 (2 per thumb) | thumb |
| 6 | 4 | fingertip |
| **Total** | **25 s** (≥ 20 s, FR-010) | wrist: −50% spread over all steps |

Durations are configurable in `look.json` → `rehearsal.stepSeconds`.

## Session length budget (SC-006: ≤ 15 min)

positioning ~1 min · normal and reveal 3–4 min · quick rinse ~0.5 min · rehearsal ~2 min with
narration · real wash ~2 min · debrief ~1 min, for **~10 min**, leaving buffer for
questions.
