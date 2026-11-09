#!/usr/bin/env python3
"""Swahili narration pipeline (research R10, tasks T094–T097).

  python3 tools/narration.py manifest
      Rebuilds ios/CleanHands/Resources/narration-manifest.json from docs/narration/script.en.md
      and script.sw.md (English source, Swahili text, review status, recording status).

  python3 tools/narration.py import <folder-with-recordings> [--synthetic]
      (--synthetic marks them as made by tools/synthesize_narration.py, not a human voice.)
      Takes the voice artist's files (N01.wav … N21.wav; .m4a/.aiff/.mp3 also accepted), checks
      all 21 are there and within the length limits, converts them to AAC m4a into
      ios/CleanHands/Resources/Narration/, and marks them as recorded in the manifest.
      Nothing is copied if any clip is missing or too long.

  python3 tools/narration.py check
      Reports each clip's length, limit, and whether it is still an English placeholder.

macOS only (uses afinfo and afconvert). No network.
"""
import json
import os
import re
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EN = os.path.join(ROOT, "docs/narration/script.en.md")
SW = os.path.join(ROOT, "docs/narration/script.sw.md")
OUT_DIR = os.path.join(ROOT, "ios/CleanHands/Resources/Narration")
MANIFEST = os.path.join(ROOT, "ios/CleanHands/Resources/narration-manifest.json")
CLIPS = [f"N{i:02d}" for i in range(1, 22)]
LONG = {"N04", "N19"}
AUDIO_EXTS = (".wav", ".m4a", ".aiff", ".aif", ".mp3", ".caf")


def limit(clip):
    return 25.0 if clip in LONG else 12.0


def table_rows(path):
    rows = {}
    for line in open(path, encoding="utf-8"):
        if not re.match(r"^\| N\d\d \|", line):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        rows[cells[0]] = cells
    return rows


def duration(path):
    out = subprocess.run(["afinfo", path], capture_output=True, text=True, check=True).stdout
    m = re.search(r"estimated duration: ([\d.]+)", out)
    return float(m.group(1)) if m else 0.0


def load_manifest():
    if os.path.exists(MANIFEST):
        return {c["id"]: c for c in json.load(open(MANIFEST, encoding="utf-8")).get("clips", [])}
    return {}


def write_manifest(recorded=None, kind="swahili"):
    en, sw, old = table_rows(EN), table_rows(SW), load_manifest()
    clips = []
    for clip in CLIPS:
        e, s = en.get(clip), sw.get(clip)
        if not e:
            sys.exit(f"{clip} is missing from {EN}")
        swahili = s[3] if s and len(s) > 3 else ""
        reviewed = bool(s and len(s) > 4 and s[4] in ("☑", "x", "X", "yes"))
        previous = old.get(clip, {}).get("recording", "placeholder-en")
        clips.append({
            "id": clip,
            "file": f"{clip}.m4a",
            "state": e[1],
            "en": e[2],
            "sw": swahili,
            "swStatus": "reviewed" if reviewed else ("draft" if swahili else "missing"),
            "recording": kind if recorded and clip in recorded else previous,
            "maxSeconds": int(limit(clip)),
        })
    with open(MANIFEST, "w", encoding="utf-8") as f:
        json.dump({"version": 2, "clips": clips}, f, indent=2, ensure_ascii=False)
        f.write("\n")
    return clips


def cmd_manifest():
    clips = write_manifest()
    drafts = sum(c["swStatus"] == "draft" for c in clips)
    reviewed = sum(c["swStatus"] == "reviewed" for c in clips)
    print(f"manifest: {len(clips)} clips, Swahili reviewed {reviewed}, draft {drafts}")


def cmd_import(folder, kind="swahili"):
    found = {}
    for name in os.listdir(folder):
        stem, ext = os.path.splitext(name)
        if ext.lower() in AUDIO_EXTS and stem.upper() in CLIPS:
            found[stem.upper()] = os.path.join(folder, name)
    problems = [f"{c}: missing" for c in CLIPS if c not in found]
    lengths = {}
    for clip, path in found.items():
        lengths[clip] = duration(path)
        if lengths[clip] > limit(clip):
            problems.append(f"{clip}: {lengths[clip]:.1f} s, longer than {limit(clip):.0f} s")
        if lengths[clip] < 0.3:
            problems.append(f"{clip}: {lengths[clip]:.1f} s, looks empty")
    if problems:
        print("Nothing imported:\n  " + "\n  ".join(sorted(problems)))
        sys.exit(1)
    with tempfile.TemporaryDirectory() as tmp:
        for clip in CLIPS:
            staged = os.path.join(tmp, f"{clip}.m4a")
            # Mono AAC, 44.1 kHz: small, starts instantly, plays offline.
            subprocess.run(["afconvert", "-f", "m4af", "-d", "aac@44100", "-c", "1", "-b", "96000",
                            found[clip], staged], check=True)
        for clip in CLIPS:
            os.replace(os.path.join(tmp, f"{clip}.m4a"), os.path.join(OUT_DIR, f"{clip}.m4a"))
    write_manifest(recorded=set(CLIPS), kind=kind)
    for clip in CLIPS:
        print(f"{clip}  {lengths[clip]:5.1f} s  (limit {limit(clip):.0f} s)")
    print(f"Imported {len(CLIPS)} Swahili clips ({kind}) into {os.path.relpath(OUT_DIR, ROOT)}.")


def cmd_check():
    manifest = load_manifest()
    over = 0
    for clip in CLIPS:
        path = os.path.join(OUT_DIR, f"{clip}.m4a")
        d = duration(path) if os.path.exists(path) else 0.0
        state = manifest.get(clip, {}).get("recording", "unknown")
        flag = "TOO LONG" if d > limit(clip) else ("MISSING" if d == 0 else "ok")
        over += flag != "ok"
        print(f"{clip}  {d:5.1f} s / {limit(clip):.0f} s  {flag:8}  {state}")
    sys.exit(1 if over else 0)


if __name__ == "__main__":
    args = sys.argv[1:]
    if args[:1] == ["manifest"]:
        cmd_manifest()
    elif args[:1] == ["import"] and len(args) in (2, 3):
        synthetic = "--synthetic" in args[2:]
        cmd_import(args[1], kind="swahili-synthetic" if synthetic else "swahili")
    elif args[:1] == ["check"]:
        cmd_check()
    else:
        sys.exit(__doc__)
