#!/usr/bin/env python3
"""Synthesize the lamp switch-on click (002 research D5, lamp-transition §7).

One soft click made of two transients 30 ms apart (the second 8 dB quieter). Each is a 1.5 ms
raised-cosine attack into band-passed noise (1-4 kHz, tau ~8 ms) over a 180 Hz thump (tau ~20 ms).
110 ms in total with a 10 ms fade-out, peak -18 dBFS. No speech, no third-party audio, fixed seed.

Usage: python3 tools/make_lamp_click.py   (from the repository root, macOS: needs afconvert)
"""
import math
import os
import random
import struct
import subprocess
import tempfile
import wave

RATE = 48_000
LENGTH = 0.110
PEAK_DBFS = -18.0
OUT = "ios/CleanHands/Resources/LampClick.caf"


def bandpass_noise(n, rng, low=1000.0, high=4000.0):
    """White noise through a one-pole high-pass then a one-pole low-pass."""
    hp_a = math.exp(-2 * math.pi * low / RATE)
    lp_a = math.exp(-2 * math.pi * high / RATE)
    out, prev_x, hp, lp = [], 0.0, 0.0, 0.0
    for _ in range(n):
        x = rng.uniform(-1, 1)
        hp = hp_a * (hp + x - prev_x)
        prev_x = x
        lp = (1 - lp_a) * hp + lp_a * lp
        out.append(lp)
    return out


def transient(n, rng):
    noise = bandpass_noise(n, rng)
    scale = max(abs(v) for v in noise) or 1
    attack = int(0.0015 * RATE)
    samples = []
    for i in range(n):
        t = i / RATE
        env = 0.5 - 0.5 * math.cos(math.pi * i / attack) if i < attack else 1.0
        click = noise[i] / scale * math.exp(-t / 0.008)
        thump = 0.6 * math.sin(2 * math.pi * 180 * t) * math.exp(-t / 0.020)
        samples.append(env * (click + thump))
    return samples


def main():
    rng = random.Random(20261104)
    total = int(LENGTH * RATE)
    buffer = [0.0] * total
    first = transient(total, rng)
    second_offset = int(0.030 * RATE)
    second = transient(total - second_offset, rng)
    second_gain = 10 ** (-8 / 20)
    for i, v in enumerate(first):
        buffer[i] += v
    for i, v in enumerate(second):
        buffer[second_offset + i] += second_gain * v

    fade = int(0.010 * RATE)
    for i in range(fade):
        buffer[total - fade + i] *= 1 - i / fade

    peak = max(abs(v) for v in buffer)
    gain = 10 ** (PEAK_DBFS / 20) / peak
    pcm = b"".join(struct.pack("<h", int(round(v * gain * 32767))) for v in buffer)

    with tempfile.TemporaryDirectory() as tmp:
        wav_path = os.path.join(tmp, "click.wav")
        with wave.open(wav_path, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(pcm)
        subprocess.run(["afconvert", "-f", "caff", "-d", "LEI16@48000", "-c", "1", wav_path, OUT], check=True)
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
