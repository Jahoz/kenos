#!/usr/bin/env python3
"""KENOS icon generator (pure stdlib, no dependencies).

Renders the app icon at every required size for Web (PWA manifest),
Android (mipmap densities) and iOS (asset catalog).

Art direction — Cosmic Zen identity:
- Void Black background (#030508) with two diffuse nebulae (indigo, teal)
- a scattered star field (deterministic seed)
- the hero "echo": a bright core wrapped in a nearly-complete charge ring
- a smaller distant echo for depth

Security posture: the single write path resolves every destination
under the project root and proves containment (is_relative_to) before
any byte is written; destinations come from the module-level literal
table, never from input.
"""
import math
import os
import struct
import zlib
from pathlib import Path

VOID = (3, 5, 8)
INDIGO = (99, 102, 241)
TEAL = (20, 184, 166)
CYAN = (34, 211, 238)
WHITE = (244, 244, 246)

BASE = Path(__file__).resolve().parent.parent

# Every destination this script may ever write: (relpath, size, pad,
# only_if_exists). Literals only — nothing dynamic, nothing input-derived.
TARGETS = (
    # Web (PWA).
    ("web/icons/Icon-512.png", 512, 0.0, False),
    ("web/icons/Icon-192.png", 192, 0.0, False),
    ("web/icons/Icon-maskable-512.png", 512, 0.10, False),
    # Android mipmaps.
    ("android/app/src/main/res/mipmap-mdpi/ic_launcher.png", 48, 0.0, False),
    ("android/app/src/main/res/mipmap-hdpi/ic_launcher.png", 72, 0.0, False),
    ("android/app/src/main/res/mipmap-xhdpi/ic_launcher.png", 96, 0.0, False),
    ("android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png", 144, 0.0, False),
    ("android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png", 192, 0.0, False),
    # iOS asset catalog (overwrite existing template filenames only).
    ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png", 20, 0.0, True),
    ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png", 40, 0.0, True),
    ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png", 60, 0.0, True),
    ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png", 29, 0.0, True),
    ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png", 58, 0.0, True),
    ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png", 87, 0.0, True),
    ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png", 40, 0.0, True),
    ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png", 80, 0.0, True),
    ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png", 120, 0.0, True),
    ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png", 120, 0.0, True),
    ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png", 180, 0.0, True),
    ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png", 76, 0.0, True),
    ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png", 152, 0.0, True),
    ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png", 167, 0.0, True),
    ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png", 1024, 0.0, True),
)


def encode_png(w: int, h: int, rgb: bytearray) -> bytes:
    """Encode an RGB buffer as a PNG — pure function, no filesystem."""

    def chunk(tag: bytes, data: bytes) -> bytes:
        return (
            struct.pack(">I", len(data))
            + tag
            + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    raw = bytearray()
    stride = w * 3
    for y in range(h):
        raw.append(0)  # filter type 0
        raw += rgb[y * stride : (y + 1) * stride]

    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + chunk(b"IEND", b"")
    )


class _Lcg:
    """Deterministic pseudo-random source for the decorative star field.

    Reproducible by design (same seed, same sky on every run); never
    used for anything security-relevant.
    """

    def __init__(self, seed: int) -> None:
        self._state = seed & 0x7FFFFFFF

    def next_float(self) -> float:
        self._state = (1103515245 * self._state + 12345) % (1 << 31)
        return self._state / (1 << 31)


def render(size: int, pad: float = 0.0) -> bytearray:
    """Render the icon art at `size`. `pad` shrinks content (maskable safe zone)."""
    w = h = size
    buf = bytearray(w * h * 3)

    # Deterministic star field.
    rng = _Lcg(1337)
    stars = [
        (
            rng.next_float(),
            rng.next_float(),
            0.6 + rng.next_float() * 1.0,
            0.15 + rng.next_float() * 0.45,
        )
        for _ in range(int(size * size / 2048) + 24)
    ]

    cx, cy = size * (0.5 - pad * 0.5) + size * pad * 0.5, size * 0.48
    core_r = max(2.0, size * 0.075)
    ring_r = size * 0.5 * (0.62 - pad)
    stroke = max(1.0, size * 0.016)
    sweep = math.radians(320)  # nearly-complete charge ring
    # Distant secondary echo.
    e2 = (size * 0.74, size * 0.24, size * 0.035, size * 0.11)

    def put(x: int, y: int, r: float, g: float, b: float, a: float) -> None:
        if 0 <= x < w and 0 <= y < h:
            i = (y * w + x) * 3
            buf[i] = max(0, min(255, int(buf[i] * (1 - a) + r * a)))
            buf[i + 1] = max(0, min(255, int(buf[i + 1] * (1 - a) + g * a)))
            buf[i + 2] = max(0, min(255, int(buf[i + 2] * (1 - a) + b * a)))

    # --- Background: subtle vertical gradient + nebulae (additive) ---
    nebulae = [
        (size * 0.26, size * 0.30, size * 0.50, INDIGO, 0.16),
        (size * 0.76, size * 0.74, size * 0.46, TEAL, 0.12),
    ]
    for y in range(h):
        t = y / h
        base_r = VOID[0] + t * 3
        base_g = VOID[1] + t * 3
        base_b = VOID[2] + t * 5
        row = y * w * 3
        for x in range(w):
            r, g, b = base_r, base_g, base_b
            for nx, ny, nr, col, na in nebulae:
                dx, dy = (x - nx) / nr, (y - ny) / nr
                d2 = dx * dx + dy * dy
                if d2 < 1.0:
                    fall = (1.0 - d2) ** 2 * na
                    r += col[0] * fall
                    g += col[1] * fall
                    b += col[2] * fall
            i = row + x * 3
            buf[i] = min(255, int(r))
            buf[i + 1] = min(255, int(g))
            buf[i + 2] = min(255, int(b))

    # --- Stars ---
    for sx, sy, sr, sa in stars:
        x0, y0 = int(sx * size), int(sy * size)
        rr = int(sr * (size / 1024) * 2) + 1
        for yy in range(y0 - rr, y0 + rr + 1):
            for xx in range(x0 - rr, x0 + rr + 1):
                d = math.hypot(xx - x0, yy - y0) / max(1, rr)
                if d <= 1.0:
                    put(xx, yy, 255, 255, 255, sa * (1.0 - d))

    # --- Hero echo: ring (track + charged sweep) ---
    x0, x1 = int(cx - ring_r - stroke), int(cx + ring_r + stroke) + 1
    y0, y1 = int(cy - ring_r - stroke), int(cy + ring_r + stroke) + 1
    for y in range(max(0, y0), min(h, y1)):
        for x in range(max(0, x0), min(w, x1)):
            dx, dy = x - cx, y - cy
            d = math.hypot(dx, dy)
            if abs(d - ring_r) > stroke / 2:
                continue
            ang = math.atan2(dx, -dy)  # 0 at top, clockwise
            if ang < 0:
                ang += 2 * math.pi
            edge = 1.0 - abs(d - ring_r) / (stroke / 2)  # anti-aliased stroke
            if ang <= sweep:
                t = ang / sweep
                col = (
                    TEAL[0] + (CYAN[0] - TEAL[0]) * t,
                    TEAL[1] + (CYAN[1] - TEAL[1]) * t,
                    TEAL[2] + (CYAN[2] - TEAL[2]) * t,
                )
                if t > 0.75:  # bright tip
                    k = (t - 0.75) / 0.25
                    col = (col[0] + (255 - col[0]) * k, col[1] + (255 - col[1]) * k, col[2] + (255 - col[2]) * k)
                put(x, y, col[0], col[1], col[2], 0.95 * edge)
            else:
                put(x, y, 255, 255, 255, 0.10 * edge)

    # --- Hero echo: core glow ---
    gr = core_r * 6
    for y in range(max(0, int(cy - gr)), min(h, int(cy + gr))):
        for x in range(max(0, int(cx - gr)), min(w, int(cx + gr))):
            d = math.hypot(x - cx, y - cy)
            if d < core_r:
                put(x, y, 255, 255, 255, 1.0)
            elif d < gr:
                t = (d - core_r) / (gr - core_r)
                a = (1.0 - t) ** 2.2
                put(x, y, CYAN[0], CYAN[1], CYAN[2], 0.55 * a)

    # --- Distant echo ---
    ex, ey, ecr, er = e2
    for y in range(max(0, int(ey - er - 2)), min(h, int(ey + er + 2))):
        for x in range(max(0, int(ex - er - 2)), min(w, int(ex + er + 2))):
            d = math.hypot(x - ex, y - ey)
            if abs(d - er) < 1.0:
                put(x, y, 255, 255, 255, 0.35)
            elif d < ecr:
                put(x, y, 255, 255, 255, 0.8)
            elif d < er:
                put(x, y, INDIGO[0], INDIGO[1], INDIGO[2], 0.25)

    return buf


def main() -> None:
    print("Rendering KENOS icons:")
    for rel, size, pad, only_if_exists in TARGETS:
        # Resolve and prove containment: a literal table entry can never
        # carry traversal, and any hypothetical '../' would be collapsed
        # by resolve() then rejected by is_relative_to.
        dest = (BASE / rel).resolve()
        if not dest.is_relative_to(BASE):
            raise ValueError(f"destination outside the project: {rel}")
        if only_if_exists and not dest.exists():
            continue
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(encode_png(size, size, render(size, pad=pad)))
        print(f"  {rel} ({size}x{size})")
    print("Done.")


if __name__ == "__main__":
    main()
