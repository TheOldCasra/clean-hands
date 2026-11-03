#!/usr/bin/env python3
"""Measure the UV look of an image: background, skin and glow palette, and glow coverage.

Used for constitution Quality Gate 3: run it on the reference images and on app screenshots
(of consenting test volunteers only), then compare the numbers.

Usage:  python3 tools/measure_glow.py IMAGE [IMAGE ...] [--bands]
Needs:  pip install pillow numpy
"""
import colorsys
import sys

import numpy as np
from PIL import Image


def hexcolor(c):
    return "#%02x%02x%02x" % tuple((np.asarray(c) * 255).round().astype(int))


def measure(path, bands=False):
    im = np.asarray(Image.open(path).convert("RGB")).astype(float) / 255
    r, g, b = im[..., 0], im[..., 1], im[..., 2]
    background = im.max(-1) < 0.09
    glow = (g > r * 1.15) & (g > b * 1.05) & (g > 0.30)
    hand = ~background
    skin = hand & ~glow & (b >= g)
    print(f"== {path}")
    print(f"  background {background.mean() * 100:.0f}% of frame")
    if skin.any():
        hsv = np.array([colorsys.rgb_to_hsv(*c) for c in im[skin][::11]])
        print(f"  skin  median {hexcolor(np.median(im[skin], 0))}  hue {np.median(hsv[:, 0]) * 360:.0f}°"
              f"  sat {np.median(hsv[:, 1]):.2f}  value {np.median(hsv[:, 2]):.2f}")
    if glow.any():
        hsv = np.array([colorsys.rgb_to_hsv(*c) for c in im[glow][::7]])
        print(f"  glow  median {hexcolor(np.median(im[glow], 0))}  highlight {hexcolor(np.percentile(im[glow], 90, 0))}"
              f"  hue {np.median(hsv[:, 0]) * 360:.0f}°")
    print(f"  glow coverage {glow.sum() / max(hand.sum(), 1) * 100:.0f}% of visible hand")
    if bands:  # assumes fingertips at the top of the image, as in ref-01
        rows = np.where(hand.any(1))[0]
        edges = np.linspace(rows.min(), rows.max(), 6).astype(int)
        for i in range(5):
            h = hand[edges[i]:edges[i + 1]]
            gl = glow[edges[i]:edges[i + 1]]
            print(f"  fifth {i + 1} from top: glow {gl.sum() / max(h.sum(), 1) * 100:.0f}% of hand")


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if not args:
        sys.exit(__doc__)
    for path in args:
        measure(path, bands="--bands" in sys.argv)
