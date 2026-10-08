#!/usr/bin/env python3
"""Generates the launcher icon and adaptive-icon foreground as original art.

Everything is drawn procedurally with Pillow - no third-party icon packs, no
licensed artwork. The mark is the game's own: a 2x2 grid of rounded tiles in the
brand ramp, with the top-left pair shown mid-merge, plus a small "+" spark at the
merge point.

Run with no arguments it regenerates everything: the Android launcher icons,
the iOS AppIcon / LaunchImage sets and the Play Store icon.

Usage:
    python3 tool/generate_icons.py [--out android/app/src/main/res]
                                   [--ios ios/Runner/Assets.xcassets]
"""
from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw

# Brand palette, matching lib/app/theme/app_colors.dart.
RAMP = [
    (0x7E, 0xE8, 0xFA),
    (0x4E, 0xCD, 0xC4),
    (0x5A, 0xC8, 0xFA),
    (0x5B, 0x8D, 0xEF),
    (0x8E, 0x7C, 0xFF),
    (0xB3, 0x6B, 0xFF),
    (0xE8, 0x6B, 0xD1),
    (0xFF, 0x7B, 0xA8),
    (0xFF, 0x9F, 0x6B),
    (0xFF, 0xB0, 0x20),
    (0xFF, 0xD4, 0x00),
    (0xB4, 0xFF, 0x39),
    (0x39, 0xFF, 0x88),
]
BG_TOP = (0x1B, 0x10, 0x35)
BG_BOTTOM = (0x2D, 0x1B, 0x4E)


def _vertical_gradient(size: int) -> Image.Image:
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y in range(size):
        t = y / max(1, size - 1)
        colour = tuple(
            int(BG_TOP[i] + (BG_BOTTOM[i] - BG_TOP[i]) * t) for i in range(3)
        )
        for x in range(size):
            px[x, y] = colour  # type: ignore[index]
    return img


def _rounded_tile(
    draw: ImageDraw.ImageDraw,
    box: tuple[float, float, float, float],
    colour: tuple[int, int, int],
    radius: float,
) -> None:
    draw.rounded_rectangle(box, radius=radius, fill=colour)


def _draw_mark(size: int, padding_ratio: float, tile_gap_ratio: float) -> Image.Image:
    """The 2x2 merge mark on a transparent layer."""
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)

    pad = size * padding_ratio
    span = size - pad * 2
    gap = span * tile_gap_ratio
    tile = (span - gap) / 2

    # Bottom-right pair is fully merged: one large tile.
    big = (pad + tile + gap, pad + tile + gap, pad + span, pad + span)
    _rounded_tile(draw, big, RAMP[4], tile * 0.26)

    # Top-left pair is mid-merge: two tiles sliding together.
    _rounded_tile(draw, (pad, pad, pad + tile, pad + tile), RAMP[0], tile * 0.26)
    _rounded_tile(
        draw,
        (pad + tile + gap * 0.55, pad, pad + tile * 2 + gap * 0.55, pad + tile),
        RAMP[1],
        tile * 0.26,
    )

    # Bottom-left tile, in the ramp, for balance.
    _rounded_tile(
        draw, (pad, pad + tile + gap, pad + tile, pad + span), RAMP[2], tile * 0.26
    )

    # Spark at the merge point.
    cx = pad + tile + gap * 0.5
    cy = pad + tile * 0.5
    r = tile * 0.16
    draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(255, 255, 255, 235))
    for angle in range(0, 360, 45):
        rad = math.radians(angle)
        x0 = cx + math.cos(rad) * r * 1.5
        y0 = cy + math.sin(rad) * r * 1.5
        x1 = cx + math.cos(rad) * r * 2.5
        y1 = cy + math.sin(rad) * r * 2.5
        draw.line((x0, y0, x1, y1), fill=(255, 255, 255, 200), width=max(1, size // 160))

    return layer


def make_icon(size: int, path: Path, padding_ratio: float) -> None:
    base = _vertical_gradient(size).convert("RGBA")
    base.alpha_composite(_draw_mark(size, padding_ratio, 0.10))
    path.parent.mkdir(parents=True, exist_ok=True)
    base.convert("RGB").save(path, "PNG", optimize=True)


# iOS AppIcon set. Filenames and pixel sizes must stay in sync with
# ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json, which is the
# unmodified upstream Flutter template.
IOS_ICONS = [
    ("Icon-App-20x20@1x.png", 20),
    ("Icon-App-20x20@2x.png", 40),
    ("Icon-App-20x20@3x.png", 60),
    ("Icon-App-29x29@1x.png", 29),
    ("Icon-App-29x29@2x.png", 58),
    ("Icon-App-29x29@3x.png", 87),
    ("Icon-App-40x40@1x.png", 40),
    ("Icon-App-40x40@2x.png", 80),
    ("Icon-App-40x40@3x.png", 120),
    ("Icon-App-60x60@2x.png", 120),
    ("Icon-App-60x60@3x.png", 180),
    ("Icon-App-76x76@1x.png", 76),
    ("Icon-App-76x76@2x.png", 152),
    ("Icon-App-83.5x83.5@2x.png", 167),
    ("Icon-App-1024x1024@1x.png", 1024),
]

# LaunchImage sizes referenced by Base.lproj/LaunchScreen.storyboard (168x185pt).
LAUNCH_IMAGES = [
    ("LaunchImage.png", 168, 185),
    ("LaunchImage@2x.png", 336, 370),
    ("LaunchImage@3x.png", 504, 555),
]


def make_launch_image(width: int, height: int, path: Path) -> None:
    """Brand launch image: gradient plate with the merge mark centred."""
    img = Image.new("RGBA", (width, height), BG_TOP + (255,))
    draw = ImageDraw.Draw(img)
    top, bottom = BG_TOP, BG_BOTTOM
    for y in range(height):
        t = y / max(1, height - 1)
        colour = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        draw.line((0, y, width, y), fill=colour)
    side = int(min(width, height) * 0.62)
    mark = _draw_mark(side, 0.04, 0.10)
    img.alpha_composite(mark, ((width - side) // 2, (height - side) // 2))
    path.parent.mkdir(parents=True, exist_ok=True)
    img.convert("RGB").save(path, "PNG", optimize=True)


def make_foreground(size: int, path: Path) -> None:
    """Adaptive-icon foreground: mark only, centred inside the safe zone."""
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    inner = int(size * 0.72)
    mark = _draw_mark(inner, 0.04, 0.10)
    offset = (size - inner) // 2
    layer.alpha_composite(mark, (offset, offset))
    path.parent.mkdir(parents=True, exist_ok=True)
    layer.save(path, "PNG", optimize=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", default="android/app/src/main/res")
    parser.add_argument("--ios", default="ios/Runner/Assets.xcassets")
    args = parser.parse_args()

    res = Path(args.out)
    ios = Path(args.ios)

    # Legacy square launcher icons.
    for bucket, size in [
        ("mipmap-mdpi", 48),
        ("mipmap-hdpi", 72),
        ("mipmap-xhdpi", 96),
        ("mipmap-xxhdpi", 144),
        ("mipmap-xxxhdpi", 192),
    ]:
        make_icon(size, res / bucket / "ic_launcher.png", padding_ratio=0.18)

    # Play Store icon.
    make_icon(512, Path("assets/images/ic_launcher_512.png"), padding_ratio=0.18)

    # Adaptive icon foreground (108dp with a 72dp safe zone).
    make_foreground(432, res / "drawable" / "ic_launcher_foreground.png")

    # iOS AppIcon - square, opaque, no alpha (App Store requirement).
    appicon = ios / "AppIcon.appiconset"
    for filename, size in IOS_ICONS:
        make_icon(size, appicon / filename, padding_ratio=0.18)

    # iOS launch image shown by LaunchScreen.storyboard.
    launch = ios / "LaunchImage.imageset"
    for filename, width, height in LAUNCH_IMAGES:
        make_launch_image(width, height, launch / filename)

    print("wrote launcher icons:")
    for path in (
        sorted(res.rglob("ic_launcher*.png"))
        + sorted((ios / "AppIcon.appiconset").glob("*.png"))
        + sorted((ios / "LaunchImage.imageset").glob("*.png"))
        + [Path("assets/images/ic_launcher_512.png")]
    ):
        print(f"  {path} ({path.stat().st_size} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
