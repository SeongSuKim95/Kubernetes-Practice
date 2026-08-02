#!/usr/bin/env python3
"""Generate a chapter thumbnail from the shared series base.

Chap line only: Audiowide (Latin) + Youandi (Hangul), under Kubernetes.

Examples:
  python3 scripts/make-chapter-thumbnail.py --chapter 1 --title "Container의 등장 배경과 Docker"
  python3 scripts/make-chapter-thumbnail.py -c 2 -t "Kubernetes의 설계 철학"
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
THUMB_DIR = ROOT / "images" / "thumbnail"
BASE_PATH = THUMB_DIR / "chapter-thumbnail-base.png"
SERIES_BASE_PATH = THUMB_DIR / "series-thumbnail-base.png"
CHAP_LATIN_FONT = ROOT / "images" / "fonts" / "Audiowide-Regular.ttf"
CHAP_HANGUL_FONT = ROOT / "images" / "fonts" / "fontYouandiModernTR.ttf"

# Layout calibrated to the 1536x1024 base
K_LEFT = 302
# Kubernetes glyph bottom ~510 (median); a bit more gap for readability
CHAP_TOP = 548
OUTLINE_RADIUS = 3
OUTLINE_COLOR = (0, 0, 0, 255)
FILL_COLOR = (255, 255, 255, 255)
CHAP_MAX_WIDTH = 1180
CHAP_MAX_FONT = 50
CHAP_MIN_FONT = 30

# Clear Chap band
CHAP_BOX = (290, 540, 1400, 700)

# Orange guide baked into chapter-thumbnail-base
MARKER_BOX = (680, 300, 931, 406)


def clear_region(base: Image.Image, box: tuple[int, int, int, int], plate_src: Image.Image) -> None:
    plate = plate_src.crop(box)
    base.paste(plate, (box[0], box[1]))


def split_script_runs(text: str) -> list[tuple[str, str]]:
    runs: list[tuple[str, str]] = []
    for ch in text:
        script = "hangul" if re.match(r"[가-힣ㄱ-ㅎㅏ-ㅣ]", ch) else "latin"
        if runs and runs[-1][0] == script:
            runs[-1] = (script, runs[-1][1] + ch)
        else:
            runs.append((script, ch))
    return runs


def render_chapter_layer(text: str, font_size: int) -> Image.Image:
    """Latin in Audiowide; Hangul in Youandi Modern."""
    latin = ImageFont.truetype(str(CHAP_LATIN_FONT), font_size)
    hangul = ImageFont.truetype(str(CHAP_HANGUL_FONT), font_size)
    fonts = {"latin": latin, "hangul": hangul}

    runs = split_script_runs(text)
    widths: list[int] = []
    heights: list[int] = []
    bboxes: list[tuple[int, int, int, int]] = []
    for script, part in runs:
        bbox = fonts[script].getbbox(part)
        bboxes.append(bbox)
        widths.append(bbox[2] - bbox[0])
        heights.append(bbox[3] - bbox[1])

    pad = OUTLINE_RADIUS + 2
    width = sum(widths) + pad * 2
    band = max(heights) if heights else font_size
    height = band + pad * 2

    layer = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)

    def stroke(s: str, font: ImageFont.FreeTypeFont, ox: int, oy: int) -> None:
        for dx in range(-OUTLINE_RADIUS, OUTLINE_RADIUS + 1):
            for dy in range(-OUTLINE_RADIUS, OUTLINE_RADIUS + 1):
                if dx * dx + dy * dy <= OUTLINE_RADIUS * OUTLINE_RADIUS + 1:
                    draw.text((ox + dx, oy + dy), s, font=font, fill=OUTLINE_COLOR)
        draw.text((ox, oy), s, font=font, fill=FILL_COLOR)

    x = pad
    for (script, part), bbox, w, h in zip(runs, bboxes, widths, heights):
        font = fonts[script]
        oy = pad + (band - h) // 2 - bbox[1]
        ox = x - bbox[0]
        stroke(part, font, ox, oy)
        x += w

    return layer


def fit_chapter_layer(text: str) -> Image.Image:
    for size in range(CHAP_MAX_FONT, CHAP_MIN_FONT - 1, -1):
        layer = render_chapter_layer(text, size)
        if layer.width <= CHAP_MAX_WIDTH:
            return layer
    return render_chapter_layer(text, CHAP_MIN_FONT)


def make_thumbnail(chapter: int, title: str, output: Path) -> Path:
    for path in (BASE_PATH, SERIES_BASE_PATH, CHAP_LATIN_FONT, CHAP_HANGUL_FONT):
        if not path.exists():
            raise FileNotFoundError(f"Missing: {path}")

    base = Image.open(BASE_PATH).convert("RGBA")
    series = Image.open(SERIES_BASE_PATH).convert("RGBA")
    if series.size != base.size:
        series = series.resize(base.size, Image.Resampling.LANCZOS)

    # Remove orange guide only (chapter base already has logo/tagline/Kubernetes)
    pad = 10
    expanded_marker = (
        max(0, MARKER_BOX[0] - pad),
        max(0, MARKER_BOX[1] - pad),
        min(base.width, MARKER_BOX[2] + pad),
        min(base.height, MARKER_BOX[3] + pad),
    )
    clear_region(base, expanded_marker, series)
    clear_region(base, CHAP_BOX, series)

    label = f"Chap{chapter:02d}. {title}"
    layer = fit_chapter_layer(label)
    px = K_LEFT - (OUTLINE_RADIUS + 2)
    py = CHAP_TOP
    base.alpha_composite(layer, (px, py))

    output.parent.mkdir(parents=True, exist_ok=True)
    base.convert("RGB").save(output, quality=95)
    return output


def main() -> None:
    parser = argparse.ArgumentParser(description="Make a chapter thumbnail")
    parser.add_argument("-c", "--chapter", type=int, required=True, help="Chapter number (e.g. 1)")
    parser.add_argument("-t", "--title", required=True, help='Chapter title after "ChapNN. "')
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        help="Output PNG path (default: images/thumbnail/weekNN-thumbnail.png)",
    )
    args = parser.parse_args()

    output = args.output
    if output is None:
        output = THUMB_DIR / f"week{args.chapter:02d}-thumbnail.png"
    elif not output.is_absolute():
        output = ROOT / output

    path = make_thumbnail(args.chapter, args.title, output)
    print(f"Wrote {path}")


if __name__ == "__main__":
    main()
