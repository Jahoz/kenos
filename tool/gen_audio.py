#!/usr/bin/env python3
"""KENOS audio asset generator (pure stdlib, no dependencies).

- drone_loop.wav  : seamless 70 Hz drone loop (frequencies are integer
                    multiples of 1/duration, amplitude LFO with a whole
                    number of cycles).
- bell_*.wav      : pure bells (inharmonic partials, exponential envelope).
- waves/wave_*.wav: the Symphonie Collective — 20 pentatonic nebula
                    notes (C-major pentatonic, 4 octaves), slow baked-in
                    ADSR envelope; the tap-and-breathe sound of V3.1.
"""
import math
import os
import random
import struct
import wave

SR = 22050
OUT = "assets/audio"


def write_wav(path: str, samples: list[float], sr: int = SR) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        frames = bytearray()
        for s in samples:
            v = int(max(-1.0, min(1.0, s)) * 32767)
            frames += struct.pack("<h", v)
        w.writeframes(bytes(frames))
        print(f"  {path} ({len(samples) / sr:.1f}s)")


def drone() -> None:
    """V3.27 — a void the ear cannot track.

    The 12 s loop was seamless but SHORT: one breath every 12 s and
    the ear locked the period within three turns — the loop FELT like
    a bug. Now 36 s of:

      * the same ~70 Hz signature (beating pair, faint octave and
        fifth, sub-warmth) on integer-cycle frequencies — seamless
        by construction, sample-exact at the wrap;
      * THREE amplitude LFOs at mutually prime cycle counts (5, 1
        and 13 per loop): the composite breathing never repeats on
        itself inside one listen;
      * a slow band of filtered noise, the void's air — made
        loop-seamless by wrapping its tail into its head with an
        equal-power crossfade AFTER filtering. Structureless, so
        there is nothing to recognize, nothing to count.
    """
    dur = 36.0
    n = int(SR * dur)
    rnd = random.Random(2026_09_07)

    def k(hz: float) -> float:
        # Nearest integer-cycle frequency: k / dur.
        return round(hz * dur) / dur

    f_lo, f_hi = k(70.0), k(70.09)   # the signature slow beat
    f_oct, f_fifth = k(140.0), k(210.0)
    f_sub = k(46.7)                  # low warmth

    # The air: low-passed noise, wrapped seamless (crossfade AFTER
    # filtering — the filter state never sees the seam).
    extra = SR  # 1 s tail, donated to the wrap
    alpha = 1 - math.exp(-2 * math.pi * 550 / SR)  # one-pole, ~550 Hz
    lp = 0.0
    air = []
    for _ in range(n + extra):
        lp += alpha * (rnd.uniform(-1.0, 1.0) - lp)
        air.append(lp)
    for i in range(extra):
        w = (i + 0.5) / extra
        air[i] = (
            air[i] * math.sin(w * math.pi / 2)
            + air[n + i] * math.cos(w * math.pi / 2)
        )
    air = air[:n]

    out = []
    for i in range(n):
        t = i / SR
        breath = 0.60 + 0.40 * math.sin(2 * math.pi * 5 / dur * t - math.pi / 2)
        swell = 0.85 + 0.15 * math.sin(2 * math.pi * 1 / dur * t - math.pi / 2)
        murmur = 0.96 + 0.04 * math.sin(2 * math.pi * 13 / dur * t + 1.0)
        tone = (
            0.46 * math.sin(2 * math.pi * f_lo * t)
            + 0.46 * math.sin(2 * math.pi * f_hi * t)
            + 0.15 * math.sin(2 * math.pi * f_oct * t + 0.7)
            + 0.06 * math.sin(2 * math.pi * f_fifth * t + 1.3)
            + 0.10 * math.sin(2 * math.pi * f_sub * t)
        )
        out.append((tone * breath * swell + air[i] * 0.030 * murmur) * 0.30)
    write_wav(f"{OUT}/drone_loop.wav", out)


def bell(path: str, freq: float, dur: float, gain: float, partials) -> None:
    n = int(SR * dur)
    out = []
    for i in range(n):
        t = i / SR
        env = math.exp(-3.0 * t) * (1 - math.exp(-80 * t))  # sharp attack, long tail
        s = sum(a * math.sin(2 * math.pi * freq * r * t + r * 0.7) for r, a in partials)
        out.append(s * env * gain)
    write_wav(path, out)


# The Symphonie Collective: C-major pentatonic across 4 octaves — every
# combination of simultaneously ringing notes is consonant by design.
PENTATONIC = [
    65.41, 73.42, 82.41, 98.00, 110.00,     # C2 - A2 (heavy / melancholy)
    130.81, 146.83, 164.81, 196.00, 220.00, # C3 - A3 (neutral / calm)
    261.63, 293.66, 329.63, 392.00, 440.00, # C4 - A4 (clear / hope)
    523.25, 587.33, 659.25, 783.99, 880.00, # C5 - A5 (crystalline / joy)
]

# Nebula envelope (baked into the asset — one play is the whole wave):
# slow 1.2 s swell, 2.4 s of presence, 2.4 s exponential exhale.
WAVE_ATTACK, WAVE_SUSTAIN, WAVE_RELEASE = 1.2, 2.4, 2.4
WAVE_SR = 11025  # naps of sound: 11 kHz mono is plenty for soft pads


def wave_note(path: str, freq: float) -> None:
    dur = WAVE_ATTACK + WAVE_SUSTAIN + WAVE_RELEASE
    n = int(WAVE_SR * dur)
    out = []
    for i in range(n):
        t = i / WAVE_SR
        if t < WAVE_ATTACK:
            env = t / WAVE_ATTACK
        elif t < WAVE_ATTACK + WAVE_SUSTAIN:
            env = 1.0
        else:
            tr = t - WAVE_ATTACK - WAVE_SUSTAIN
            env = math.exp(-2.6 * tr / WAVE_RELEASE)
        # Nebula timbre: fundamental plus soft octave and fifth (a triangle
        # smoothed out — brightness without harshness).
        s = (
            1.00 * math.sin(2 * math.pi * freq * t)
            + 0.28 * math.sin(2 * math.pi * freq * 2 * t + 0.4)
            + 0.12 * math.sin(2 * math.pi * freq * 3 * t + 0.9)
        )
        out.append(s * env * 0.42)
    write_wav(path, out, sr=WAVE_SR)


if __name__ == "__main__":
    print("Synthesizing KENOS audio assets:")
    drone()
    bell(f"{OUT}/bell_seal.wav", 659.25, 2.8, 0.42, ((1, 1.0), (2.76, 0.35), (5.4, 0.12)))   # E5
    bell(f"{OUT}/bell_send.wav", 783.99, 2.8, 0.42, ((1, 1.0), (2.76, 0.35), (5.4, 0.12)))   # G5
    bell(f"{OUT}/bell_reveal.wav", 1046.50, 3.0, 0.40, ((1, 1.0), (2.76, 0.30), (5.4, 0.10))) # C6
    bell(f"{OUT}/bell_burn.wav", 220.0, 3.8, 0.45, ((1, 1.0), (2.0, 0.30), (3.0, 0.10)))     # A3, dark
    os.makedirs(f"{OUT}/waves", exist_ok=True)
    for i, freq in enumerate(PENTATONIC):
        wave_note(f"{OUT}/waves/wave_{i:02d}.wav", freq)
    print("Done.")
