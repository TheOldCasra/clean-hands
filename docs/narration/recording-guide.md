# Recording the Swahili narration

For the voice artist and the person recording her. Until a voice artist is available, the app
uses a synthetic Swahili voice (research R10 amendment): after the text is reviewed, regenerate it
with `<venv>/bin/python tools/synthesize_narration.py <folder>` and import it with
`python3 tools/narration.py import <folder> --synthetic`. A human recording replaces it whenever
one is made. Record only from the **reviewed** lines in
[script.sw.md](script.sw.md) (every "Reviewed" box ticked), never from the draft.

## Who and where

- One woman's voice for all 21 clips, approved by Barefoot College International Zanzibar
  (research R10). The same voice throughout, so participants hear one calm guide.
- A quiet room with soft furnishings (curtains, cushions) to stop echo; no fan, no traffic, no
  call to prayer in the background. Phones on silent.
- Any decent phone voice-memo app or a USB microphone is enough. Hold it about 20 cm from the
  mouth, slightly to the side, at the same distance for every clip.

## How to read

- Warm, calm and unhurried, like explaining something to a friend; never like a warning.
- Short pause after each sentence. N04 and N19 (the simulation explanation and the debrief) may
  be slower; they matter most.
- Keep each clip within its limit: 12 seconds, except N04 and N19 (25 seconds). If a clip runs
  long, read it a little faster or ask the reviewer to shorten the wording.
- Record 2–3 takes of each clip and keep the best one. Leave about half a second of silence at
  the start and end.

## Files

- One file per clip, named exactly by its clip number: `N01.wav`, `N02.wav` … `N21.wav`.
  (`.m4a` from a phone is fine too.)
- Mono if possible, 44.1 or 48 kHz. No music, no effects, no added echo.
- Put all 21 files in one folder and send it to the app team by cable, USB stick or AirDrop.
  Do not send it over WhatsApp (it re-compresses the audio).

## What the app team does with them

```bash
python3 tools/narration.py import <folder-with-the-21-files>
```

This checks that all 21 clips are there and within their limits, converts them for the app, and
marks them as recorded in `narration-manifest.json`. If anything is missing or too long, nothing
is changed and the problem is listed. Then the app is rebuilt and partner staff listen to the
whole session once more (quickstart V13) before the pilot.

`python3 tools/narration.py check` shows at any time which clips are still English
placeholders.
