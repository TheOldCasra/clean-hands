# Quickstart & Validation Guide: UV Germ Visualization Study MVP

**Feature**: `001-uv-germ-visualization` | **Plan**: [plan.md](plan.md)

How to prove the feature works end to end, in the order the constitution's quality gates need.
This guide covers validation only; build details belong in `tasks.md`.

## Prerequisites

- A Mac with current Xcode, and an Apple Developer Program membership (research R1, R13).
- At least one iPad running iPadOS 17 or later, ideally the same model as at the centre (R2).
- Physical setup A (overhead stand) or B (mirror clip), plus a matte dark cloth (R4, R9).
- Python 3 with `pillow`, `numpy`, and `jsonschema` for the tools.
- Test volunteers who have agreed to be filmed for testing. They are not study participants.
- Reference images in `docs/reference/` (present locally; git-ignored).

## Scenarios

| # | Scenario | How | Expected outcome | Proves |
|---|---|---|---|---|
| V1 | **Offline launch** | Airplane Mode on, launch the app, open Device Check | App works; Device Check shows model, OS, render fps, and tracking Hz | FR-027, R2 |
| V2 | **Consent gate** | Register `PIL-01` without consent, try to start | Camera stays off. After recording consent with a form reference, the camera starts | FR-017, US2-1 |
| V3 | **Reveal** | Run the US1 acceptance scenarios 1–8 live with a volunteer | All pass: glow within 2 s, stays on the hands, palm/back patterns, both hands, view switch, simulation badge, spoken intro | US1, FR-001–009 |
| V4 | **Pattern determinism** | Unit tests for pattern generation; then `PIL-02` runs Session 1 and Session 2, with screenshots of the open palm in each | Tests green; both screenshots show the same pattern | FR-006, US2-2 |
| V5 | **Rehearsal** | Volunteer follows all 6 steps; mid-step, one hand leaves the view | The step pauses after 1 s and resumes when the hand returns; matching regions fade; ≥ 20 s active rubbing in the log | US3, FR-010–012 |
| V6 | **Tracking gates** | Debug build → replay harness on the test clips (R14) | Report shows SC-001 ≥ 95% within 2 s, SC-002 ≤ 1/20 poses spill, and SC-003 met on the participant-matched set (darker skin tones, henna, jewelry) | Gates 1–2 |
| V7 | **Visual QA** | iPad screenshots of a volunteer's open palm and cupped hands, then `python3 tools/measure_glow.py <shots> --bands`, then side-by-side review with `docs/reference/` | Numbers within `contracts/look-config.md` targets; ≥ 2 of 3 reviewers say "looks like the reference" | Gate 3, FR-002, FR-004 |
| V8 | **Face guard** | Volunteer leans over until her face enters the frame | Screen blanks, session pauses, `faceGuardTriggered` logged; resumes when the face leaves | Principle VII |
| V9 | **Export** | Export from the facilitator panel, then validate `events.jsonl` against `contracts/session-event-log.schema.json` (`python3 -m jsonschema` or a short script) and inspect the CSVs | 0 schema errors; no names, contact details, or images anywhere | FR-026, export contract |
| V10 | **Withdrawal** | Withdraw `PIL-02`, then export | No rows or events for `PIL-02` remain | FR-026 |
| V11 | **No networking** | Search the app source for networking APIs (URLSession, the Network framework, web views); run a session in Airplane Mode | None found; session works | Gate 4, FR-027 |
| V12 | **Full mock visit** | Facilitator runs a complete Session 1 with a volunteer, timed | ≤ 15 min; facilitator never reads screen text aloud | SC-005, SC-006 |
| V13 | **Swahili content review** | Partner staff watch V12 with the final Swahili audio | Sign-off recorded; no cultural or religious concerns | Gate 5, FR-014–015 |

## Before the first `ZNZ` session

1. V1–V13 all pass on every study iPad, in the session room.
2. A pilot with 2–3 Swahili-speaking volunteers outside the cohort, using `PIL-` codes. Their data
   is excluded from analysis.
3. Pre-registration finalized and time-stamped (see `contracts/measures.md`).
4. Ethics approval(s), partner permission, and printed Swahili consent materials in hand
   (constitution, Research Ethics).
5. Guided Access configured on each iPad, Airplane Mode on, and iPad passcode set.
