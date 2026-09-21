"""Render the approved Pruevia book mark into platform PNG assets.

The SVG files remain the design source of truth. This small renderer keeps the
Flutter web, Android and iOS derivatives reproducible without adding a runtime
SVG dependency to the patient app.
"""

from __future__ import annotations

from pathlib import Path
from typing import Iterable

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
TEAL = (15, 118, 110, 255)
WHITE = (255, 255, 255, 255)


def cubic(start: tuple[float, float], c1: tuple[float, float], c2: tuple[float, float], end: tuple[float, float], steps: int = 16) -> list[tuple[float, float]]:
    points: list[tuple[float, float]] = []
    for index in range(steps + 1):
        t = index / steps
        inverse = 1 - t
        points.append((
            inverse**3 * start[0] + 3 * inverse**2 * t * c1[0] + 3 * inverse * t**2 * c2[0] + t**3 * end[0],
            inverse**3 * start[1] + 3 * inverse**2 * t * c1[1] + 3 * inverse * t**2 * c2[1] + t**3 * end[1],
        ))
    return points


def quadratic(start: tuple[float, float], control: tuple[float, float], end: tuple[float, float], steps: int = 12) -> list[tuple[float, float]]:
    points: list[tuple[float, float]] = []
    for index in range(steps + 1):
        t = index / steps
        inverse = 1 - t
        points.append((
            inverse**2 * start[0] + 2 * inverse * t * control[0] + t**2 * end[0],
            inverse**2 * start[1] + 2 * inverse * t * control[1] + t**2 * end[1],
        ))
    return points


def left_page_points() -> list[tuple[float, float]]:
    points = quadratic((32, 46), (32, 32), (47, 34))
    points += cubic((47, 34), (87, 38), (116, 49), (128, 68))[1:]
    points.append((128, 218))
    points += cubic((128, 218), (105, 193), (78, 183), (47, 181))[1:]
    points += quadratic((47, 181), (32, 180), (32, 166))[1:]
    return points


def right_page_points() -> list[tuple[float, float]]:
    points = cubic((136, 68), (150, 49), (181, 36), (218, 24))
    points += quadratic((218, 24), (232, 20), (232, 36))[1:]
    points.append((232, 157))
    points += quadratic((232, 157), (232, 167), (221, 168))[1:]
    points += cubic((221, 168), (182, 172), (155, 188), (136, 218))[1:]
    return points


def letter_p_points() -> list[tuple[float, float]]:
    points = [(56, 176), (56, 75)]
    points += cubic((56, 75), (78, 77), (99, 80), (109, 87))[1:]
    points += cubic((109, 87), (121, 95), (126, 107), (124, 120))[1:]
    points += cubic((124, 120), (122, 133), (114, 141), (103, 144))[1:]
    points += cubic((103, 144), (93, 146), (83, 143), (74, 140))[1:]
    points.append((74, 181))
    points += cubic((74, 181), (68, 179), (62, 178), (56, 176))[1:]
    return points


def letter_p_counter_points() -> list[tuple[float, float]]:
    points = [(74, 94), (74, 121)]
    points += cubic((74, 121), (84, 123), (93, 127), (99, 125))[1:]
    points += cubic((99, 125), (104, 123), (107, 119), (107, 113))[1:]
    points += cubic((107, 113), (107, 106), (104, 101), (98, 99))[1:]
    points += cubic((98, 99), (92, 96), (84, 95), (74, 94))[1:]
    return points


def transform(points: list[tuple[float, float]], left: float, top: float, scale: float) -> list[tuple[float, float]]:
    return [(left + x * scale, top + y * scale) for x, y in points]


def draw_mark(canvas: Image.Image, left: float, top: float, size: float, *, page_color: tuple[int, int, int, int] = WHITE, cutout_color: tuple[int, int, int, int] = TEAL) -> None:
    draw = ImageDraw.Draw(canvas)
    scale = size / 256
    draw.polygon(transform(left_page_points(), left, top, scale), fill=page_color)
    draw.polygon(transform(right_page_points(), left, top, scale), fill=page_color)
    draw.polygon(transform(letter_p_points(), left, top, scale), fill=cutout_color)
    draw.polygon(transform(letter_p_counter_points(), left, top, scale), fill=page_color)

    line_width = max(2, round(15 * scale))
    for start, end in (((158, 95), (210, 76)), ((158, 127), (197, 113))):
        transformed = transform([start, end], left, top, scale)
        draw.line(transformed, fill=cutout_color, width=line_width)
        radius = line_width / 2
        for x, y in transformed:
            draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=cutout_color)


def render_icon(size: int, *, maskable: bool = False, rounded: bool = False) -> Image.Image:
    scale = 4
    render_size = max(size * scale, 64)
    image = Image.new("RGBA", (render_size, render_size), TEAL if not rounded else (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    if rounded:
        radius = round(render_size * 56 / 256)
        draw.rounded_rectangle((0, 0, render_size - 1, render_size - 1), radius=radius, fill=TEAL)
    inset = render_size * .07 if maskable else 0
    draw_mark(image, inset, inset, render_size - (2 * inset))
    result = image.resize((size, size), Image.Resampling.LANCZOS)
    return result


def render_adaptive_foreground(size: int) -> Image.Image:
    """Render the mark inside Android's 66/108 dp adaptive-icon safe zone."""
    scale = 4
    render_size = max(size * scale, 108)
    image = Image.new("RGBA", (render_size, render_size), (0, 0, 0, 0))
    mark_size = render_size * .78
    offset = (render_size - mark_size) / 2
    draw_mark(
        image,
        offset,
        offset,
        mark_size,
        page_color=WHITE,
        cutout_color=(0, 0, 0, 0),
    )
    return image.resize((size, size), Image.Resampling.LANCZOS)


def save_icon(path: Path, size: int, *, maskable: bool = False, rounded: bool = False) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image = render_icon(size, maskable=maskable, rounded=rounded)
    image.convert("RGBA" if rounded else "RGB").save(path, format="PNG", optimize=True)


def save_adaptive_foreground(path: Path, size: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    render_adaptive_foreground(size).save(path, format="PNG", optimize=True)


def render_splash(width: int, height: int, mark_size: int) -> Image.Image:
    image = Image.new("RGBA", (width, height), WHITE)
    mark = render_icon(mark_size, rounded=True)
    image.alpha_composite(mark, ((width - mark_size) // 2, (height - mark_size) // 2))
    return image


def save_splash(path: Path, width: int, height: int, mark_size: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    render_splash(width, height, mark_size).save(path, format="PNG", optimize=True)


def main() -> None:
    patient = ROOT / "apps" / "patient"

    save_icon(patient / "web" / "favicon.png", 16, rounded=True)
    for size in (192, 512):
        save_icon(patient / "web" / "icons" / f"Icon-{size}.png", size)
        save_icon(patient / "web" / "icons" / f"Icon-maskable-{size}.png", size, maskable=True)

    android_sizes = {
        "mdpi": 48,
        "hdpi": 72,
        "xhdpi": 96,
        "xxhdpi": 144,
        "xxxhdpi": 192,
    }
    for density, size in android_sizes.items():
        save_icon(patient / "android" / "app" / "src" / "main" / "res" / f"mipmap-{density}" / "ic_launcher.png", size)
        save_adaptive_foreground(
            patient / "android" / "app" / "src" / "main" / "res" / f"drawable-{density}" / "ic_launcher_foreground.png",
            round(size * 108 / 48),
        )
    save_icon(patient / "android" / "app" / "src" / "main" / "res" / "drawable" / "launch_logo.png", 192)

    ios_icons: Iterable[tuple[str, int]] = (
        ("Icon-App-20x20@1x.png", 20), ("Icon-App-20x20@2x.png", 40), ("Icon-App-20x20@3x.png", 60),
        ("Icon-App-29x29@1x.png", 29), ("Icon-App-29x29@2x.png", 58), ("Icon-App-29x29@3x.png", 87),
        ("Icon-App-40x40@1x.png", 40), ("Icon-App-40x40@2x.png", 80), ("Icon-App-40x40@3x.png", 120),
        ("Icon-App-60x60@2x.png", 120), ("Icon-App-60x60@3x.png", 180),
        ("Icon-App-76x76@1x.png", 76), ("Icon-App-76x76@2x.png", 152),
        ("Icon-App-83.5x83.5@2x.png", 167), ("Icon-App-1024x1024@1x.png", 1024),
    )
    ios_dir = patient / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    for filename, size in ios_icons:
        save_icon(ios_dir / filename, size)

    launch_dir = patient / "ios" / "Runner" / "Assets.xcassets" / "LaunchImage.imageset"
    save_splash(launch_dir / "LaunchImage.png", 168, 185, 96)
    save_splash(launch_dir / "LaunchImage@2x.png", 336, 370, 192)
    save_splash(launch_dir / "LaunchImage@3x.png", 504, 555, 288)


if __name__ == "__main__":
    main()
