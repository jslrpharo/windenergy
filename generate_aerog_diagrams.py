from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent
IMG_DIR = ROOT / "tutorials" / "en" / "img"
FONT_BOLD = Path(r"C:\Windows\Fonts\cambriab.ttf")
FONT_REGULAR = Path(r"C:\Windows\Fonts\cambria.ttc")

COLORS = {
    "text": "#1d1d1d",
    "controller_fill": "#f4c7a0",
    "converter_fill": "#c9d98d",
    "box_outline": "#434343",
    "mask": "#ffffff",
}


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(FONT_BOLD if bold else FONT_REGULAR), size)


def multiline_center(draw: ImageDraw.ImageDraw, center: tuple[int, int], lines: list[str], text_font: ImageFont.FreeTypeFont, fill: str) -> None:
    boxes = [draw.textbbox((0, 0), line, font=text_font) for line in lines]
    widths = [box[2] - box[0] for box in boxes]
    heights = [box[3] - box[1] for box in boxes]
    spacing = 2
    total_height = sum(heights) + spacing * (len(lines) - 1)
    y = center[1] - total_height // 2
    for line, width, height in zip(lines, widths, heights):
        draw.text((center[0] - width // 2, y), line, fill=fill, font=text_font)
        y += height + spacing


def mask_label(draw: ImageDraw.ImageDraw, rect: tuple[int, int, int, int]) -> None:
    draw.rectangle(rect, fill=COLORS["mask"])


def draw_label(
    draw: ImageDraw.ImageDraw,
    rect: tuple[int, int, int, int],
    lines: list[str],
    *,
    size: int,
    bold: bool = True,
) -> None:
    mask_label(draw, rect)
    multiline_center(
        draw,
        ((rect[0] + rect[2]) // 2, (rect[1] + rect[3]) // 2),
        lines,
        font(size, bold=bold),
        COLORS["text"],
    )


def draw_box_label(
    draw: ImageDraw.ImageDraw,
    rect: tuple[int, int, int, int],
    lines: list[str],
    *,
    fill: str,
    text_size: int,
) -> None:
    draw.rectangle(rect, fill=fill, outline=COLORS["box_outline"], width=1)
    multiline_center(
        draw,
        ((rect[0] + rect[2]) // 2, (rect[1] + rect[3]) // 2 + 1),
        lines,
        font(text_size, bold=True),
        COLORS["text"],
    )


DIAGRAMS = {
    "Aerog full-converter-cabezon-en.png": {
        "labels": [
            {"rect": (4, 0, 176, 52), "lines": ["Permanent Magnet", "Generator"], "size": 14},
        ],
        "boxes": [
            {"rect": (300, 52, 422, 109), "lines": ["FULL", "CONVERTER"], "fill": COLORS["converter_fill"], "size": 14},
            {"rect": (188, 167, 342, 214), "lines": ["CONTROLLER"], "fill": COLORS["controller_fill"], "size": 14},
        ],
    },
    "Aerog full-converter-gearbox-en.png": {
        "labels": [
            {"rect": (90, 27, 184, 53), "lines": ["Gearbox"], "size": 14},
            {"rect": (184, 0, 380, 52), "lines": ["Permanent Magnet", "Generator"], "size": 14},
        ],
        "boxes": [
            {"rect": (300, 52, 422, 109), "lines": ["FULL", "CONVERTER"], "fill": COLORS["converter_fill"], "size": 14},
            {"rect": (188, 167, 342, 214), "lines": ["CONTROLLER"], "fill": COLORS["controller_fill"], "size": 14},
        ],
    },
    "Aerog palafija-en.png": {
        "labels": [
            {"rect": (0, 14, 62, 46), "lines": ["Hub"], "size": 13},
            {"rect": (58, 24, 178, 56), "lines": ["Gearbox"], "size": 14},
            {"rect": (180, 0, 344, 54), "lines": ["Squirrel Cage", "Generator"], "size": 14},
        ],
        "boxes": [
            {"rect": (155, 167, 342, 213), "lines": ["CONTROLLER"], "fill": COLORS["controller_fill"], "size": 14},
        ],
    },
    "Aerog dfig-en.png": {
        "labels": [
            {"rect": (92, 27, 184, 53), "lines": ["Gearbox"], "size": 14},
            {"rect": (182, 0, 430, 54), "lines": ["Wound Rotor", "Induction Generator"], "size": 14},
        ],
        "boxes": [
            {"rect": (299, 82, 422, 147), "lines": ["BACK-TO-BACK", "CONVERTER"], "fill": COLORS["converter_fill"], "size": 13},
            {"rect": (188, 167, 342, 214), "lines": ["CONTROLLER"], "fill": COLORS["controller_fill"], "size": 14},
        ],
    },
    "Aerog rrc-en.png": {
        "labels": [
            {"rect": (0, 10, 62, 68), "lines": ["Hub"], "size": 13},
            {"rect": (58, 22, 172, 72), "lines": ["Gearbox"], "size": 14},
            {"rect": (158, 0, 414, 72), "lines": ["Wound Rotor", "Induction Generator"], "size": 13},
        ],
        "boxes": [
            {"rect": (155, 201, 342, 247), "lines": ["CONTROLLER"], "fill": COLORS["controller_fill"], "size": 14},
        ],
    },
    "Aerog active-stall-en.png": {
        "labels": [
            {"rect": (0, 10, 62, 68), "lines": ["Hub"], "size": 13},
            {"rect": (58, 22, 172, 72), "lines": ["Gearbox"], "size": 14},
            {"rect": (180, 0, 344, 56), "lines": ["Squirrel Cage", "Generator"], "size": 14},
        ],
        "boxes": [
            {"rect": (155, 191, 342, 237), "lines": ["CONTROLLER"], "fill": COLORS["controller_fill"], "size": 14},
        ],
    },
}


def render(name: str) -> None:
    path = IMG_DIR / name
    image = Image.open(path).convert("RGB")
    draw = ImageDraw.Draw(image)
    cfg = DIAGRAMS[name]

    for label in cfg["labels"]:
        draw_label(draw, label["rect"], label["lines"], size=label["size"])

    for box in cfg["boxes"]:
        draw_box_label(draw, box["rect"], box["lines"], fill=box["fill"], text_size=box["size"])

    image.save(path)


def main() -> None:
    parser = argparse.ArgumentParser(description="Standardize labels and box styles on the original aerogenerator diagrams.")
    parser.add_argument("--only", choices=sorted(DIAGRAMS), help="Process only one diagram.")
    args = parser.parse_args()

    names = [args.only] if args.only else list(DIAGRAMS)
    for name in names:
        render(name)
        print(f"updated {name}")


if __name__ == "__main__":
    main()