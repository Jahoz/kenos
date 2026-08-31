#!/usr/bin/env python3
"""KENOS icon generator (pure stdlib, no dependencies).

Renders the app icon at every required size for Web (PWA manifest),
Android (mipmap densities) and iOS (asset catalog).

Art direction — Cosmic Zen identity:
- Void Black background (#030508) with two diffuse nebulae (indigo, teal)
- a scattered star field (deterministic seed)
- the hero "echo": a bright core wrapped in a nearly-complete charge ring
- a smaller distant echo for depth
"""
import math
import os
import random
import struct
import zlib

VOID = (3, 5, 8)
INDIGO = (99, 102, 241)
TEAL = (20, 184, 166)
CYAN = (34, 211, 238)
WHITE = (244, 244, 246)

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def write_png(path: str, w: int, h: int, rgb: bytearray) -> None:
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

    png = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + chunk(b"IEND", b"")
    )
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(png)
    print(f"  {os.path.relpath(path, BASE)} ({w}x{h})")


def render(size: int, pad: float = 0.0) -> bytearray:
    """Render the icon art at `size`. `pad` shrinks content (maskable safe zone)."""
    w = h = size
    buf = bytearray(w * h * 3)

    # Deterministic star field.
    rng = random.Random(1337)
    stars = [
        (rng.random(), rng.random(), 0.6 + rng.random() * 1.0, 0.15 + rng.random() * 0.45)
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

    # Web (PWA).
    write_png(f"{BASE}/web/icons/Icon-512.png", 512, 512, render(512))
    write_png(f"{BASE}/web/icons/Icon-192.png", 192, 192, render(192))
    write_png(f"{BASE}/web/icons/Icon-maskable-512.png", 512, 512, render(512, pad=0.10))

    # Android mipmaps.
    densities = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    for name, size in densities.items():
        write_png(
            f"{BASE}/android/app/src/main/res/mipmap-{name}/ic_launcher.png",
            size,
            size,
            render(size),
        )

    # iOS asset catalog (overwrite existing template filenames).
    ios = f"{BASE}/ios/Runner/Assets.xcassets/AppIcon.appiconset"
    ios_sizes = {
        "Icon-App-20x20@1x.png": 20, "Icon-App-20x20@2x.png": 40, "Icon-App-20x20@3x.png": 60,
        "Icon-App-29x29@1x.png": 29, "Icon-App-29x29@2x.png": 58, "Icon-App-29x29@3x.png": 87,
        "Icon-App-40x40@1x.png": 40, "Icon-App-40x40@2x.png": 80, "Icon-App-40x40@3x.png": 120,
        "Icon-App-60x60@2x.png": 120, "Icon-App-60x60@3x.png": 180,
        "Icon-App-76x76@1x.png": 76, "Icon-App-76x76@2x.png": 152,
        "Icon-App-83.5x83.5@2x.png": 167, "Icon-App-1024x1024@1x.png": 1024,
    }
    for fname, size in ios_sizes.items():
        path = f"{ios}/{fname}"
        if os.path.exists(path):
            write_png(path, size, size, render(size))

    print("Done.")


if __name__ == "__main__":
    main()
