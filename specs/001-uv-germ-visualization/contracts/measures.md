# Contract: Paper Measures (Baseline and Follow-up)

**Administered by**: the facilitator, orally in Swahili, with picture cards. No reading is
required of the participant.
**Entered by**: the researcher, into `measures.csv` (one row per participant per visit).
**Rule**: baseline and follow-up use identical cards, wording, and order (constitution
Principle III). The final Swahili wording is approved by partner staff (Principle VII).

## Materials (to be produced, see tasks)

- **Key-moment cards (K1–K5)**: one picture each.
  - K1 after using the toilet
  - K2 before preparing food
  - K3 before eating
  - K4 after cleaning a child
  - K5 after coughing, sneezing, or blowing the nose

  The final set is agreed with partner staff.
- **Frequency card**: 3 pictures for "never", "sometimes", and "always" (in the past 3 days),
  about washing **with soap**.
- **Hand-outline card**: palm and back outlines, with zones Z1 fingertips, Z2 thumbs, Z3 between
  the fingers, Z4 back of the hand, Z5 wrists, Z6 palm.
- **Vividness card** (follow-up only): 3 pictures for "I don't remember it", "a little", and
  "very clearly".
- **Demonstration checklist**: a one-page form for the facilitator.

## measures.csv columns

| Column | Visit | Values | Item (summary of the oral question) |
|---|---|---|---|
| participant_code | both | `ZNZ-xx` | |
| visit | both | `baseline` / `followup` | |
| date | both | YYYY-MM-DD | |
| facilitator_code | both | `Fx` | |
| soap_home_access | baseline | 0 none / 1 sometimes / 2 always | Do you have soap at home for washing hands? |
| k1_soap_freq … k5_soap_freq | both | 0 never / 1 sometimes / 2 always | In the past 3 days, at [moment], did you wash your hands with soap? |
| demo_m1 … demo_m6 | both | 0/1 | During her normal handwashing demonstration, she performed motion 1…6 (WHO technique) |
| demo_soap_used | both | 0/1 | Used soap in the demonstration |
| demo_rub_seconds | both | integer | Seconds of rubbing (facilitator times it) |
| missed_z1 … missed_z6 | both | 0/1 | She pointed to zone Zx when asked "which places do people often miss?" |
| recall_image_free | followup | 0/1 | Asked "What do you remember from the sessions?", she mentions the glowing hands without prompting (SC-009) |
| k1_image_came_to_mind … k5_image_came_to_mind | followup | 0 no / 1 sometimes / 2 yes | During the last 5 days, at [moment], did the picture of the glowing hands come to your mind? |
| vividness | followup | 0 / 1 / 2 | How clearly can you see the glowing hands in your mind now? |
| told_others | followup | 0/1 | Did you tell anyone about it? |
| told_others_who | followup | free text, no names | e.g., "daughter", "neighbor" |
| attached_rating | followup | 0 / 1 / 2 / 3 / 4 | Picture scale: did the marks look attached to your hands? Top two = 3, 4 (SC-004) |
| needed_reading_help | followup | 0/1 | Facilitator's record from the sessions: did she need on-screen text read aloud? (SC-005) |
| felt_uncomfortable | followup | 0/1 + note | Was anything uncomfortable, confusing, or not right for you? (SC-010) |
| culturally_inappropriate | followup | 0/1 + note | Was anything not respectful of your culture or religion? (SC-010) |
| uv_tracer_coverage_note | followup | free text | Descriptive observations from the real UV tracer demonstration at the end (FR-024) |
| notes | both | free text | No names |

## Analysis notes (pre-registration draft)

- **Design**: single group, within person, n = 8. Report every participant individually plus
  medians. No significance tests are planned as confirmatory.
- **Primary (memory without the device)**: `recall_image_free` and the
  `k*_image_came_to_mind` items at follow-up.
- **Secondary (behavior and knowledge)**: change from baseline to follow-up in `k*_soap_freq`,
  `demo_m*` total, `demo_rub_seconds`, and `missed_z*` total.
- **Feasibility and acceptability**: SC-004, SC-005, SC-008, SC-010, and the interview themes.
- The pre-registration is to be finalized and time-stamped before the first `ZNZ` session.
