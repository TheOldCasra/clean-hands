<!--
Sync Impact Report
- Version change: (template) → 1.0.0
- Modified principles: n/a (initial ratification)
- Added principles: I. Truthful Simulation; II. Privacy by Design; III. Research Validity First;
  IV. Pretrained Models First; V. Motivate, Don't Frighten; VI. MVP Simplicity
- Added sections: Research Ethics & Data Constraints; Development Workflow & Quality Gates
- Removed sections: none
- Follow-up TODOs:
  - TODO(ETHICS_BODY): name the ethics committee / IRB that will review the study once known.
  - Reference glow images were mentioned by the project owner but not yet added to the repo;
    add them under docs/reference/ before visual QA (see Quality Gates).
-->

# Clean Hands (UV Germ Visualization MVP) Constitution

## Core Principles

### I. Truthful Simulation (NON-NEGOTIABLE)

The product MUST NOT claim, imply, or let a participant reasonably believe that it detects real
microbes. A phone camera cannot see bacteria; every glow pattern is a simulation.

- Every screen showing the glow effect MUST carry a visible "simulation" indicator.
- The post-wash view MUST present residual glow as "areas most people miss", never as an
  assessment of this participant's actual washing.
- Any study design that withholds the simulated nature of the effect during the session MUST be
  approved by the ethics body in advance and MUST end with a debrief.

Rationale: the goal is lasting behavior change built on trust. Misleading people about
contamination is ethically unacceptable and would also confound the study.

### II. Privacy by Design

- Camera frames MUST be processed on the device and MUST NOT be stored, uploaded, or logged.
- Study data MUST be pseudonymous (participant code, no names, no images) and limited to what the
  pre-registered analysis needs.
- No third-party analytics, ads, or tracking SDKs.

Rationale: participants are pointing a camera at their own bodies; the study cannot need their
images, so the product never keeps them.

### III. Research Validity First

- Every feature MUST trace to the study question: does the glow visualization help people
  remember to wash their hands when no app or device is present?
- Study arms MUST differ only in the variable under test (the glow visualization); handwashing
  information content, session length, and researcher script MUST be matched across arms.
- Arm assignment MUST be randomized and recorded; outcomes and analysis MUST be written down
  (pre-registered) before the first real participant session.
- Session events needed for analysis (start, arm, step completions, aborts) MUST be logged with
  timestamps.

Rationale: a polished app that cannot answer the research question is a failed MVP.

### IV. Pretrained Models First

- Hand detection/segmentation MUST start from existing pretrained or foundation models.
- A custom-trained model is permitted only after a documented evaluation shows the pretrained
  option misses the acceptance thresholds in the spec (accuracy, latency, or skin-tone parity).
- Any model (pretrained or custom) MUST be evaluated on a test set spanning a broad range of skin
  tones, hand sizes, and lighting before use with participants.

Rationale: speed to a testable MVP, and fairness across participants.

### V. Motivate, Don't Frighten

- Visuals and copy MUST be non-shaming and non-disgusting: glowing marks, not bugs, gore, or
  "dirty" labels on people.
- Every glow reveal MUST be followed by a concrete, achievable action (how to wash well).
- Participants MUST be able to stop at any time, from any screen, without penalty.
- Content MUST be age-appropriate for the youngest included participant group.

Rationale: fear appeals can backfire or feed contamination anxiety; memorable-and-positive is the
target.

### VI. MVP Simplicity

- Build the smallest thing that answers the study question. No accounts, no backend, no
  cross-session sync unless the spec requires it.
- Prefer off-the-shelf tools (e.g., an existing survey platform) over building equivalents.
- Added complexity MUST be justified in the plan's Complexity Tracking table.

Rationale: the deliverable is evidence, not a product.

## Research Ethics & Data Constraints

- No real participant session before ethics approval (TODO(ETHICS_BODY)) and informed consent.
  If minors are included: parental/guardian consent plus the child's own assent.
- Comply with applicable data-protection law (e.g., GDPR where it applies): a lawful basis,
  a retention period, a deletion procedure, and a named data controller.
- Exported study data MUST be free of direct identifiers; the key linking codes to people (if
  any) MUST be stored separately from study data.
- A short pilot (3–5 people) MUST run before main data collection; pilot data is excluded from
  the analysis.

## Development Workflow & Quality Gates

- Spec-Driven Development with Spec Kit: constitution → specify → clarify → plan → tasks →
  analyze → implement → converge. No implementation work without an approved spec and plan.
- Gates before participant use:
  1. Hand overlay meets the spec's performance and accuracy criteria on every target device.
  2. Skin-tone parity check passed (Principle IV).
  3. Visual QA: glow look reviewed against the reference images in docs/reference/.
  4. Privacy check: no camera frame leaves the device (network inspection during a session).
  5. Both study arms reviewed side by side for matched content (Principle III).
- Testing happens on the real target devices, not only on desktop emulators.

## Governance

- This constitution supersedes conflicting practices, specs, and plans. Plans MUST include a
  Constitution Check; violations require a documented justification or a spec change.
- Amendments: propose the change, record the rationale, bump the version, update the date.
- Versioning: MAJOR for removing or redefining a principle; MINOR for adding a principle or
  materially expanding guidance; PATCH for wording fixes.
- Compliance review: run /speckit-analyze before /speckit-implement and re-check the Quality
  Gates before the pilot and before main data collection.

**Version**: 1.0.0 | **Ratified**: 2026-11-03 | **Last Amended**: 2026-11-03
