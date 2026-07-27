#!/usr/bin/env python3
"""Generate a chapter thumbnail from the shared series base.

Only the chapter number and title change; logo, Kubernetes title,
and the Youandi tagline stay fixed.

Examples:
  python3 scripts/make-chapter-thumbnail.py --chapter 1 --title Introduction
  python3 scripts/make-chapter-thumbnail.py -c 2 -t "Pod Basics" -o images/week02-thumbnail.png
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
BASE_PATH = ROOT / "images" / "chapter-thumbnail-base.png"
SERIES_BASE_PATH = ROOT / "images" / "series-thumbnail-base.png"
CHAP_FONT_PATH = ROOT / "images" / "fonts" / "Audiowide-Regular.ttf"

# Layout calibrated to the 1536x1024 base (left-aligned with "Kubernetes")
K_LEFT = 302
CHAP_TOP = 568
CHAP_FONT_SIZE = 42
OUTLINE_RADIUS = 3
OUTLINE_COLOR = (0, 0, 0, 255)
FILL_COLOR = (255, 255, 255, 255)

# Region that holds the Chap line — cleared from series-thumbnail-base before redraw
CHAP_BOX = (298, 555, 980, 645)  # left, top, right, bottom


def format_label(chapter: int, title: str) -> str:
    return f"Chap {chapter:02d}. {title}"


def clear_chapter_region(base: Image.Image) -> Image.Image:
    """Replace the Chap text area with clean pixels from the series base art."""
    series = Image.open(SERIES_BASE_PATH).convert("RGBA")
    if series.size != base.size:
        series = series.resize(base.size, Image.Resampling.LANCZOS)
    plate = series.crop(CHAP_BOX)
    out = base.copy()
    out.paste(plate, (CHAP_BOX[0], CHAP_BOX[1]))
    return out


def render_chapter_layer(text: str) -> Image.Image:
    font = ImageFont.truetype(str(CHAP_FONT_PATH), CHAP_FONT_SIZE)
    bbox = font.getbbox(text)
    pad = OUTLINE_RADIUS + 2
    layer = Image.new(
        "RGBA",
        (bbox[2] - bbox[0] + pad * 2, bbox[3] - bbox[1] + pad * 2),
        (0, 0, 0, 0),
    )
    draw = ImageDraw.Draw(layer)
    ox, oy = pad - bbox[0], pad - bbox[1]

    for dx in range(-OUTLINE_RADIUS, OUTLINE_RADIUS + 1):
        for dy in range(-OUTLINE_RADIUS, OUTLINE_RADIUS + 1):
            if dx * dx + dy * dy <= OUTLINE_RADIUS * OUTLINE_RADIUS + 1:
                draw.text((ox + dx, oy + dy), text, font=font, fill=OUTLINE_COLOR)
    draw.text((ox, oy), text, font=font, fill=FILL_COLOR)
    return layer


def make_thumbnail(chapter: int, title: str, output: Path) -> Path:
    if not BASE_PATH.exists():
        raise FileNotFoundError(f"Missing base image: {BASE_PATH}")
    if not SERIES_BASE_PATH.exists():
        raise FileNotFoundError(f"Missing series base: {SERIES_BASE_PATH}")
    if not CHAP_FONT_PATH.exists():
        raise FileNotFoundError(f"Missing chapter font: {CHAP_FONT_PATH}")

    base = Image.open(BASE_PATH).convert("RGBA")

    # Chap 01 on the base is the original raster — keep it as-is.
    if chapter == 1 and title == "Introduction":
        output.parent.mkdir(parents=True, exist_ok=True)
        base.convert("RGB").save(output)
        return output

    base = clear_chapter_region(base)
    label = format_label(chapter, title)
    layer = render_chapter_layer(label)

    px = K_LEFT - (OUTLINE_RADIUS + 2)
    py = CHAP_TOP
    base.alpha_composite(layer, (px, py))

    output.parent.mkdir(parents=True, exist_ok=True)
    base.convert("RGB").save(output)
    return output


def main() -> None:
    parser = argparse.ArgumentParser(description="Make a chapter thumbnail")
    parser.add_argument("-c", "--chapter", type=int, required=True, help="Chapter number (e.g. 1)")
    parser.add_argument("-t", "--title", required=True, help='Chapter title (e.g. "Introduction")')
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        help="Output PNG path (default: images/weekNN-thumbnail.png)",
    )
    args = parser.parse_args()

    output = args.output
    if output is None:
        output = ROOT / "images" / f"week{args.chapter:02d}-thumbnail.png"
    elif not output.is_absolute():
        output = ROOT / output

    path = make_thumbnail(args.chapter, args.title, output)
    print(f"Wrote {path}")


if __name__ == "__main__":
    main()
