<!--
Sync Impact Report
- Version change: 1.0.0 → 2.0.0 (MAJOR: Principle III redefined)
- Modified principles:
  - III. Research Validity First: comparison is now within-person (baseline vs. app-free period);
    randomized arms no longer required (only 8 participants who share daily program life).
  - V. Motivate, Don't Frighten: "youngest included group" wording replaced by reference to VII.
- Added principles: VII. Culturally Grounded & Accessible
- Modified sections: Research Ethics & Data Constraints (ethics bodies, partner consent,
  voluntariness, Swahili consent, pilot outside the cohort); Development Workflow & Quality Gates
  (gate 2 now targets the participant group's skin tones and henna; gate 5 replaced by
  cultural and language review).
- Removed sections: none
- Follow-up TODOs:
  - TODO(ETHICS_BODY): confirm which approvals apply: ZAHREC (Zanzibar Health Research Ethics
    Committee, at ZAHRI) and the researcher's home institution, plus written permission from
    Barefoot College International Zanzibar.
  - Reference glow images still to be added under docs/reference/.
-->

# Clean Hands (UV Germ Visualization MVP) Constitution

## Core Principles

### I. Truthful Simulation (NON-NEGOTIABLE)

The product MUST NOT claim, imply, or let a participant reasonably believe that it detects real
microbes. A phone camera cannot see bacteria; every glow pattern is a simulation.

- Every screen showing the glow effect MUST carry a visible simulation indicator (icon plus
  Swahili label), and the first reveal MUST include a spoken explanation.
- The post-wash view MUST present residual glow as "places most people miss", never as an
  assessment of this participant's actual washing.
- Any study design that withholds the simulated nature of the effect MUST be approved by the
  ethics body in advance and MUST end with a debrief.

Rationale: lasting behavior change is built on trust. Misleading people about contamination is
ethically unacceptable and would also confound the study.

### II. Privacy by Design

- Camera frames MUST be processed on the device and MUST NOT be stored, uploaded, or logged.
- Study data MUST be pseudonymous (participant code, no names, no images) and limited to what the
  pre-registered analysis needs.
- No third-party analytics, ads, or tracking SDKs. The app MUST work fully offline.

Rationale: participants point a camera at their own bodies; the study never needs their images.

### III. Research Validity First

- Every feature MUST trace to the study question: does the glow visualization help people
  remember to wash their hands when no app or device is present?
- The comparison is within-person: the same participant before the first session (baseline)
  and after the app-free period. Measures, wording, and administration MUST be identical at
  both points.
- Study design, outcomes, and analysis MUST be written down (pre-registered) before the first
  real participant session.
- Session events needed for analysis MUST be logged with timestamps.
- No contact about handwashing between the last session and the follow-up beyond what the
  protocol defines; reminders would contaminate the app-free test.
- If a comparison arm is added in a later study, arms MUST differ only in the visualization and
  assignment MUST be randomized.

Rationale: with 8 participants, the MVP's value is a clean, honest signal about memorability,
acceptability, and direction of change, not a statistical proof.

### IV. Pretrained Models First

- Hand detection/segmentation MUST start from existing pretrained or foundation models.
- A custom-trained model is permitted only after a documented evaluation shows the pretrained
  option misses the acceptance thresholds in the spec (accuracy, latency, or skin-tone parity).
- Any model MUST be evaluated, before use with participants, on hands that match the participant
  group: darker skin tones, adult women's hands, henna patterns, rings and bangles, and the
  lighting at the session location.

Rationale: speed to a testable MVP, and fairness to the people who will actually use it.

### V. Motivate, Don't Frighten

- Visuals and copy MUST be non-shaming and non-disgusting: glowing marks, not bugs, gore, or
  "dirty" labels on people.
- Every glow reveal MUST be followed by a concrete, achievable action (how to wash well).
- Participants MUST be able to stop at any time, from any screen, without penalty.
- Content MUST be appropriate for the participant group as reviewed under Principle VII.

Rationale: fear appeals can backfire; memorable-and-positive is the target.

### VI. MVP Simplicity

- Build the smallest thing that answers the study question. No accounts, no backend, no
  cross-device sync unless the spec requires it.
- Prefer off-the-shelf or paper tools (e.g., printed pictorial response cards) over building
  equivalents.
- Added complexity MUST be justified in the plan's Complexity Tracking table.

Rationale: the deliverable is evidence, not a product.

### VII. Culturally Grounded & Accessible

- All participant-facing content MUST be in Swahili, translated by a native speaker and
  back-translated, and MUST be usable without reading (spoken narration, icons, demonstration).
- Content MUST be reviewed and approved by Barefoot College International Zanzibar staff before
  use, including its fit with participants' religious practice.
- Content MUST NOT suggest that ritual washing (wudu) is inadequate; handwashing with soap at key
  moments is framed as complementary to existing practice.
- The camera setup MUST frame hands only, never faces or bodies.
- Sessions SHOULD be facilitated by a Swahili-speaking woman from, or approved by, the partner
  organization.

Rationale: the intervention only works if participants can understand it, trust it, and feel
respected by it.

## Research Ethics & Data Constraints

- No real participant session before ethics approval (TODO(ETHICS_BODY)), written permission
  from Barefoot College International Zanzibar, and informed consent from each participant.
- Consent MUST be explained aloud in Swahili; the form of consent (signature, thumbprint, or
  witnessed oral consent) follows the ethics approval.
- Participation MUST be voluntary and MUST NOT affect a participant's standing in the Solar
  Mamas or Enriche program; this MUST be stated during consent.
- Comply with applicable data-protection law: a lawful basis, a retention period, a deletion
  procedure, and a named data controller.
- Exported study data MUST be free of direct identifiers; any key linking codes to people MUST
  be stored separately and, where possible, kept by the partner organization.
- A pilot MUST run before the first participant session, with Swahili-speaking volunteers who are
  not in the cohort (e.g., 2–3 partner staff). Pilot data is excluded from the analysis.

## Development Workflow & Quality Gates

- Spec-Driven Development with Spec Kit: constitution → specify → clarify → plan → tasks →
  analyze → implement → converge. No implementation work without an approved spec and plan.
- Gates before participant use:
  1. Hand overlay meets the spec's performance and accuracy criteria on every study device,
     offline, in the session room's lighting.
  2. Participant-group check passed (Principle IV): darker skin tones, henna, jewelry.
  3. Visual QA: glow look reviewed against the reference images in docs/reference/.
  4. Privacy check: no camera frame leaves the device (network off and inspected during pilot).
  5. Language and cultural review signed off by partner staff (Principle VII).
- Testing happens on the real study devices, not only on desktop emulators.

## Governance

- This constitution supersedes conflicting practices, specs, and plans. Plans MUST include a
  Constitution Check; violations require a documented justification or a spec change.
- Amendments: propose the change, record the rationale, bump the version, update the date.
- Versioning: MAJOR for removing or redefining a principle; MINOR for adding a principle or
  materially expanding guidance; PATCH for wording fixes.
- Compliance review: run /speckit-analyze before /speckit-implement and re-check the Quality
  Gates before the pilot and before the first participant session.

**Version**: 2.0.0 | **Ratified**: 2026-11-03 | **Last Amended**: 2026-11-03
