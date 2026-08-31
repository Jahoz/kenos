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
    dur = 12.0
    n = int(SR * dur)
    # Frequencies = k / dur (integer k) => continuous phase across the loop.
    f_beat_lo = 840 / dur    # 70.00 Hz
    f_beat_hi = 841 / dur    # ~70.08 Hz (slow 1/12 Hz beat)
    f_oct = 1680 / dur       # octave
    f_fifth = 2522 / dur     # high fifth, discrete
    lfo = 1 / dur            # breathing: exactly one cycle per loop
    out = []
    for i in range(n):
        t = i / SR
        amp = 0.62 + 0.38 * math.sin(2 * math.pi * lfo * t - math.pi / 2)
        s = (
            0.5 * math.sin(2 * math.pi * f_beat_lo * t)
            + 0.5 * math.sin(2 * math.pi * f_beat_hi * t)
            + 0.16 * math.sin(2 * math.pi * f_oct * t + 0.7)
            + 0.05 * math.sin(2 * math.pi * f_fifth * t + 1.3)
        )
        out.append(s * amp * 0.30)
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
