#!/usr/bin/env python3
"""Shrink a board painting into the thumbnail the map panel draws beside each level.

Usage::

    python tools/board_thumb.py <board.png> [out.png] [target_height]

Writes ``<board>_thumb.png`` by default, 144px tall.

WHY A SEPARATE FILE rather than drawing the painting itself scaled down: the panel lives on
the TITLE SCREEN, where no board is loaded at all, and there are three of them. Pointing the
panel at the real paintings would pull ~9 MB of texture into the menu on a phone to draw
three postage stamps. The thumbnails are ~1% of that.

It reuses cut_sprites.box_downscale for the same reason that function exists: averaging every
source pixel in ONCE, here, is sharper than letting the GPU reduce 1672px to 128px each
frame, and it takes the file size down with it. The target is ~2x the drawn size (the panel
draws these at 128x72), which is cut_sprites' own rule -- enough for the mip chain to have
something real to work with, without shipping a second copy of the board.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from cut_sprites import box_downscale
from png_reader import Png, write_rgba

DEFAULT_HEIGHT = 144


def to_rgba(img: Png) -> bytes:
    """Board paintings have no alpha (PNG colour type 2), and box_downscale reads four
    channels per pixel, so widen rather than assume."""
    if img.channels == 4:
        return img.pixels
    out = bytearray(img.width * img.height * 4)
    src = img.pixels
    for i in range(img.width * img.height):
        s, d = i * img.channels, i * 4
        out[d] = src[s]
        out[d + 1] = src[s + 1]
        out[d + 2] = src[s + 2]
        out[d + 3] = 255
    return bytes(out)


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    src = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 else os.path.splitext(src)[0] + "_thumb.png"
    target = int(sys.argv[3]) if len(sys.argv) > 3 else DEFAULT_HEIGHT

    img = Png(src)
    w, h, px = box_downscale(img.width, img.height, to_rgba(img), target)
    write_rgba(out, w, h, px)
    print("  %s %dx%d -> %s %dx%d (%.0f KB)"
          % (os.path.basename(src), img.width, img.height,
             os.path.basename(out), w, h, os.path.getsize(out) / 1024.0))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
