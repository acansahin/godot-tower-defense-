#!/usr/bin/env python3
"""Cut an MP3 down to a looping section, and fade its ends, WITHOUT re-encoding it.

The background music arrived as a 5:38 track. Shipping all of it costs ~7.5 MB in the web
build and the APK for something the player hears once, so the game plays a ~2 minute
section on repeat instead. This is the tool that cuts it.

It never decodes the audio, which is the whole point: everything in `tools/` is stdlib-only
(see `png_reader.py`), and an MP3 decoder is not something to write for a file trim. Two
tricks make that possible:

* **Cutting is dropping frames.** An MPEG-1 Layer III stream is a sequence of self-describing
  frames, each 1152 samples long. Walking the headers gives an exact time for every frame, so
  "keep 0-117.5s" is "copy the frames whose start time falls in that window" — byte-identical
  audio, no quality loss, no encoder needed.
* **Fading is rewriting `global_gain`.** Each frame's side info carries a `global_gain` per
  granule per channel, and the decoder scales that granule by `2**((global_gain-210)/4)` — so
  one step is ~1.505 dB. Subtracting steps across the last N frames IS a fade-out, applied
  without touching a single spectral coefficient. (This is the same lever `mp3gain` pulls.)

Fades matter here because the file is a LOOP: Godot restarts the stream at the end, so
wherever the cut lands, the last sample is followed immediately by the first. A hard cut
mid-phrase clicks. Two defences, in order of importance:

1. **Cut where the music is already quiet.** `--report` prints a loudness curve derived from
   the same `global_gain` fields — a free, no-decode proxy for level — so the cut point is
   READ off the track rather than guessed at a round number. On this track the dip at 117.1s
   sits ~12 dB under the surrounding bars and matches the level of the intro it loops back
   to, which is why the shipped cut is 117.5s and not a tidy 120.
2. **Fade the ends into that dip.** A fade-out over the last second or so and a shorter
   fade-in at the head make the seam a breath instead of an edge.

Note the fade is quantised to 1.505 dB steps and applied per FRAME (24 ms), which is far
finer than the ear tracks on a fade this long — but it also means a fade shorter than about
a tenth of a second has too few steps to be smooth. Don't ask for one.

MPEG-1 Layer III only. MPEG-2/2.5 put one granule in a smaller side info block and the
offsets below would be wrong, so those are rejected loudly rather than silently mangled.

Usage::

    python tools/trim_mp3.py <in.mp3> --report
    python tools/trim_mp3.py <in.mp3> <out.mp3> --end 117.5 --fade-in 0.8 --fade-out 1.5

The shipped track was cut with exactly that second line.
"""

import argparse
import sys

# Bitrate table (kbps) and sample rates for MPEG-1, indexed by the header's 4- and 2-bit
# fields. `None` marks the "free" and "bad" values a real frame never uses.
BITRATES = [None, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, None]
SAMPLE_RATES = [44100, 48000, 32000, None]

SAMPLES_PER_FRAME = 1152      # MPEG-1 Layer III, fixed
GAIN_STEP_DB = 1.5051500      # 20*log10(2**0.25): one global_gain step
FADE_FLOOR_DB = -60.0         # Treat anything below this as silence rather than chasing 0.


class Frame:
    """One MPEG audio frame: where it starts, how long it is, and how to reach its gains."""

    __slots__ = ("offset", "length", "nch", "crc", "si_start", "si_len", "gain_bits")

    def __init__(self, offset, length, nch, crc):
        self.offset = offset
        self.length = length
        self.nch = nch
        self.crc = crc                       # True when the frame carries a CRC-16
        self.si_start = offset + 4 + (2 if crc else 0)
        self.si_len = 17 if nch == 1 else 32
        # Side info layout: main_data_begin(9) + private_bits(5 mono / 3 stereo) +
        # scfsi(4 per channel), then 2 granules x nch blocks of 59 bits each, with
        # global_gain 21 bits into a block (after part2_3_length(12) + big_values(9)).
        base = 9 + (5 if nch == 1 else 3) + 4 * nch
        self.gain_bits = [base + i * 59 + 21 for i in range(2 * nch)]


def _read_id3v2_size(data):
    """Bytes to skip for a leading ID3v2 tag (0 if there is none)."""
    if len(data) < 10 or data[:3] != b"ID3":
        return 0
    size = (data[6] << 21) | (data[7] << 14) | (data[8] << 7) | data[9]
    end = 10 + size
    if data[5] & 0x10:      # footer present
        end += 10
    return end


def parse_frames(data):
    """Walk the stream and return its frames in order.

    Resyncs a byte at a time on anything that isn't a valid MPEG-1 Layer III header, which
    is what carries us over ID3 remnants, album art and the odd garbage byte between frames.
    """
    frames = []
    off = _read_id3v2_size(data)
    end = len(data)
    while off + 4 <= end:
        if data[off] != 0xFF or (data[off + 1] & 0xE0) != 0xE0:
            off += 1
            continue
        h = data[off:off + 4]
        version = (h[1] >> 3) & 3
        layer = (h[1] >> 1) & 3
        crc = (h[1] & 1) == 0
        bitrate = BITRATES[(h[2] >> 4) & 0xF]
        rate = SAMPLE_RATES[(h[2] >> 2) & 3]
        padding = (h[2] >> 1) & 1
        mode = (h[3] >> 6) & 3
        if layer != 1 or bitrate is None or rate is None:
            off += 1
            continue
        if version != 3:
            raise SystemExit(
                "this file is not MPEG-1 (version field %d); the side-info offsets this "
                "tool writes into only hold for MPEG-1 Layer III" % version)
        length = 144 * bitrate * 1000 // rate + padding
        if off + length > end:
            break
        frames.append(Frame(off, length, 1 if mode == 3 else 2, crc))
        off += length
    if not frames:
        raise SystemExit("no MPEG-1 Layer III frames found")
    return frames, SAMPLE_RATES[(data[frames[0].offset + 2] >> 2) & 3]


def is_metadata_frame(data, frame):
    """True for the Xing/Info/VBRI frame encoders put first: a header, not music.

    It has to go. Its frame count and seek table describe the ORIGINAL length, so leaving it
    in a trimmed file makes every decoder that trusts it report the wrong duration.
    """
    tag_at = frame.si_start + frame.si_len
    if data[tag_at:tag_at + 4] in (b"Xing", b"Info"):
        return True
    return data[frame.offset + 36:frame.offset + 40] == b"VBRI"


def read_gains(data, frame):
    """The frame's global_gain values, one per granule per channel."""
    bits = int.from_bytes(data[frame.si_start:frame.si_start + frame.si_len], "big")
    total = frame.si_len * 8
    return [(bits >> (total - p - 8)) & 0xFF for p in frame.gain_bits]


def write_gains(buf, frame, gains):
    """Write global_gain values back into `buf` (a bytearray of the whole file)."""
    total = frame.si_len * 8
    bits = int.from_bytes(buf[frame.si_start:frame.si_start + frame.si_len], "big")
    for p, g in zip(frame.gain_bits, gains):
        shift = total - p - 8
        bits = (bits & ~(0xFF << shift)) | (g << shift)
    buf[frame.si_start:frame.si_start + frame.si_len] = bits.to_bytes(frame.si_len, "big")
    if frame.crc:
        _rewrite_crc(buf, frame)


def _rewrite_crc(buf, frame):
    """Recompute the frame's CRC-16 after its side info changed.

    Most decoders ignore it, but a strict one drops the frame — and a dropped frame is a
    hole in the audio that only shows up on the player that checks.
    """
    crc = 0xFFFF
    payload = bytes(buf[frame.offset + 2:frame.offset + 4]) + \
        bytes(buf[frame.si_start:frame.si_start + frame.si_len])
    for byte in payload:
        crc ^= byte << 8
        for _ in range(8):
            crc = ((crc << 1) ^ 0x8005) & 0xFFFF if crc & 0x8000 else (crc << 1) & 0xFFFF
    buf[frame.offset + 4:frame.offset + 6] = crc.to_bytes(2, "big")


def _attenuation_steps(factor):
    """Amplitude factor (0..1) -> whole global_gain steps to subtract."""
    if factor <= 0.0:
        db = FADE_FLOOR_DB
    else:
        import math
        db = max(FADE_FLOOR_DB, 20.0 * math.log10(factor))
    return int(round(-db / GAIN_STEP_DB))


def report(data, frames, rate, bucket):
    """Print a loudness-over-time curve, so a cut point can be chosen by reading it.

    The value is the mean global_gain of every granule in the bucket. It is a PROXY — it
    ignores the spectral coefficients the gain scales — but section breaks, drops and outros
    all show up in it clearly, which is all that is being looked for.
    """
    spf = SAMPLES_PER_FRAME / rate
    per_bucket = max(1, int(round(bucket / spf)))
    print("  t(s)   level   (mean global_gain over %.2fs)" % (per_bucket * spf))
    for i in range(0, len(frames), per_bucket):
        chunk = frames[i:i + per_bucket]
        gains = [g for f in chunk for g in read_gains(data, f)]
        mean = sum(gains) / len(gains)
        print("%7.2f %7.1f  %s" % (i * spf, mean, "#" * max(0, int(mean - 140))))


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("source")
    ap.add_argument("dest", nargs="?", help="omit with --report to only measure")
    ap.add_argument("--start", type=float, default=0.0, help="first second to keep")
    ap.add_argument("--end", type=float, default=None, help="second to stop at (exclusive)")
    ap.add_argument("--fade-in", type=float, default=0.0, help="fade-in length in seconds")
    ap.add_argument("--fade-out", type=float, default=0.0, help="fade-out length in seconds")
    ap.add_argument("--report", action="store_true",
                    help="print the loudness curve and exit")
    ap.add_argument("--bucket", type=float, default=1.0,
                    help="seconds per line of --report output")
    args = ap.parse_args(argv)

    data = open(args.source, "rb").read()
    frames, rate = parse_frames(data)
    spf = SAMPLES_PER_FRAME / rate
    music = [f for f in frames if not is_metadata_frame(data, f)]
    print("%s: %d frames, %.2fs, %d Hz, %d ch"
          % (args.source, len(music), len(music) * spf, rate, music[0].nch))

    if args.report:
        report(data, music, rate, args.bucket)
        return 0
    if args.dest is None:
        ap.error("a destination is required unless --report is given")

    first = int(round(args.start / spf))
    last = len(music) if args.end is None else min(len(music), int(round(args.end / spf)))
    kept = music[first:last]
    if not kept:
        raise SystemExit("the requested window keeps no frames")

    buf = bytearray(data)
    fade_in = int(round(args.fade_in / spf))
    fade_out = int(round(args.fade_out / spf))
    for i, frame in enumerate(kept):
        drop = 0
        # Both ramps touch silence at the very edge of the file, so the seam the loop
        # makes is silence-to-silence rather than two different non-zero levels.
        if fade_in and i < fade_in:
            drop = max(drop, _attenuation_steps(i / float(fade_in)))
        if fade_out and i >= len(kept) - fade_out:
            drop = max(drop, _attenuation_steps((len(kept) - 1 - i) / float(fade_out)))
        if drop:
            write_gains(buf, frame, [max(0, g - drop) for g in read_gains(buf, frame)])

    out = bytearray()
    for frame in kept:
        out += buf[frame.offset:frame.offset + frame.length]
    open(args.dest, "wb").write(bytes(out))
    print("%s: %d frames, %.2fs, %d bytes (was %d), fade %.2fs in / %.2fs out"
          % (args.dest, len(kept), len(kept) * spf, len(out), len(data),
             fade_in * spf, fade_out * spf))
    return 0


if __name__ == "__main__":
    sys.exit(main())
