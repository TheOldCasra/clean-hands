# Contract: Study Data Export

**Produced by**: Facilitator panel → "Export study data" (iPadOS share sheet).
**Consumed by**: the researcher's analysis (spreadsheet or R/Python).

An export is a single folder named `cleanhands-export-<deviceShortId>-<YYYYMMDD-HHmm>`. The
researcher merges exports from several iPads by `participant_code`.

```text
cleanhands-export-…/
├── manifest.json          # export metadata
├── participants.csv       # one row per participant on this iPad
├── sessions.csv           # one row per session
├── events.jsonl           # all session events, schema: session-event-log.schema.json
└── session_summary.csv    # derived per-session metrics (computed at export time)
```

## manifest.json

`{ "exportedAt", "appVersion", "deviceModel", "osVersion", "schemaVersion": "v1", "counts": { "participants", "sessions", "events" } }`

## participants.csv

| Column | Type | Notes |
|---|---|---|
| participant_code | string | `ZNZ-01`…`ZNZ-08`, `PIL-xx` |
| is_pilot | 0/1 | 1 for `PIL-` codes |
| consent_recorded_at | ISO 8601 | |
| consent_form_ref | string | Paper form reference number |
| withdrawn | 0/1 | Withdrawn participants are removed entirely; this column exists for audit before deletion |

## sessions.csv

| Column | Type | Notes |
|---|---|---|
| session_id | UUID | |
| participant_code | string | |
| visit | `session1`/`session2` | |
| facilitator_code | string | |
| camera_setup | `overheadRear`/`mirrorFront` | |
| device_model, os_version, app_version | string | |
| started_at, ended_at | ISO 8601 | |
| outcome | `completed`/`aborted` | |
| abort_reason | string or empty | |

## session_summary.csv (derived)

| Column | Type | Derivation | Used for |
|---|---|---|---|
| session_id | UUID | | |
| duration_s | number | ended_at − started_at | SC-006 |
| time_to_first_hand_ms | integer | first `handsDetected` in the `positioning` state | SC-001 |
| uv_view_seconds | number | total time in the `uvReveal` state with view = uv | descriptive |
| view_switch_count | integer | count of `viewSwitched` | descriptive |
| steps_completed | 0–6 | count of distinct `stepCompleted` | FR-010 |
| rehearsal_active_s | number | sum of `activeSeconds` at `stepCompleted` | FR-010 (≥ 20 s) |
| pause_count | integer | count of `stepPaused` | edge cases |
| face_guard_count | integer | count of `faceGuardTriggered` | Principle VII check |
| min_quality_level | high/medium/low | lowest `qualityLevelChanged` level | device fit |

## Guarantees

- No column or event contains names, contact details, voice recordings, or images (FR-026, FR-027).
- Times are in ISO 8601 with a timezone offset.
- An export never deletes data from the iPad. Deletion happens only through "Withdraw participant".
