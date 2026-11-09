#!/usr/bin/env python3
"""Synthesize the 21 Swahili narration clips offline with Meta's MMS-TTS Swahili model
(facebook/mms-tts-swh), reading the Swahili column of docs/narration/script.sw.md.

Used because no voice artist is available (research R10, amended 2026-11-09). The text still needs
a native speaker's review and the voice the partner's approval before participants hear it.
Model licence: CC-BY-NC 4.0 (non-commercial research use).

Setup, once (outside the repository; about 1 GB of packages, 150 MB model on first run):
  python3.12 -m venv <venv> && <venv>/bin/pip install torch transformers numpy

Then:
  <venv>/bin/python tools/synthesize_narration.py <output-folder> [--rate 0.95] [--seed 7]
  python3 tools/narration.py import <output-folder> --synthetic

Runs on the CPU, no network after the model download, same seed = same audio.
"""
import argparse
import os
import re
import sys
import wave

import numpy as np
import torch
from transformers import AutoTokenizer, VitsModel

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SW = os.path.join(ROOT, "docs/narration/script.sw.md")
MODEL = "facebook/mms-tts-swh"


def swahili_lines():
    lines = {}
    for line in open(SW, encoding="utf-8"):
        if re.match(r"^\| N\d\d \|", line):
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            lines[cells[0]] = cells[3]
    missing = [f"N{i:02d}" for i in range(1, 22) if not lines.get(f"N{i:02d}")]
    if missing:
        sys.exit(f"No Swahili text for: {', '.join(missing)}")
    return lines


def sentences(text):
    """Split at sentence ends so each is spoken with a natural pause between."""
    parts = re.split(r"(?<=[.?!:])\s+", text.strip())
    return [p for p in parts if p]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("out")
    parser.add_argument("--rate", type=float, default=0.95, help="speaking rate, 1.0 = model default")
    parser.add_argument("--seed", type=int, default=7)
    parser.add_argument("--pause", type=float, default=0.35, help="seconds between sentences")
    args = parser.parse_args()
    os.makedirs(args.out, exist_ok=True)

    tokenizer = AutoTokenizer.from_pretrained(MODEL)
    model = VitsModel.from_pretrained(MODEL)
    model.eval()
    rate = model.config.sampling_rate
    gap = np.zeros(int(args.pause * rate), dtype=np.float32)
    edge = np.zeros(int(0.25 * rate), dtype=np.float32)

    def speak(text, speaking_rate, tight=False):
        model.speaking_rate = speaking_rate
        lead = edge[: int(0.1 * rate)] if tight else edge
        pause = gap[: int(0.2 * rate)] if tight else gap
        pieces = [lead]
        for i, sentence in enumerate(sentences(text)):
            torch.manual_seed(args.seed + i)
            inputs = tokenizer(sentence, return_tensors="pt")
            with torch.no_grad():
                audio = model(**inputs).waveform[0].numpy()
            pieces += [audio.astype(np.float32), pause]
        pieces[-1] = lead
        return np.concatenate(pieces)

    for clip, text in swahili_lines().items():
        limit = 25.0 if clip in ("N04", "N19") else 12.0
        speaking_rate = args.rate
        audio = speak(text, speaking_rate)
        # A clip over its limit gets shorter silences and is read a little faster, never more than
        # 20 % above the base rate.
        cap = args.rate * 1.2
        while len(audio) / rate > limit - 0.2 and speaking_rate < cap:
            speaking_rate = min(cap, speaking_rate * (len(audio) / rate) / (limit - 0.3))
            audio = speak(text, speaking_rate, tight=True)
        if len(audio) / rate > limit:
            print(f"{clip}: still {len(audio) / rate:.1f} s at the fastest allowed rate; shorten its Swahili text")
        peak = float(np.max(np.abs(audio))) or 1.0
        pcm = (audio / peak * 0.7 * 32767).astype("<i2")  # about -3 dBFS
        path = os.path.join(args.out, f"{clip}.wav")
        with wave.open(path, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(rate)
            w.writeframes(pcm.tobytes())
        note = "" if speaking_rate == args.rate else f"  (read at {speaking_rate:.2f} to fit {limit:.0f} s)"
        print(f"{clip}  {len(audio) / rate:5.1f} s{note}")


if __name__ == "__main__":
    main()
