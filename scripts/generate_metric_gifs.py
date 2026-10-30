"""Generate matching transparent dashboard XP and trophy GIFs.

The supplied Animated/Fire.gif is the style/timing reference: output stays at
108x150, uses its 26 frame durations, transparency, and infinite loop setting.
"""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
ANIMATED = ROOT / "Animated"
SIZE = (108, 150)
SCALE = 4
FRAME_COUNT = 26

BLUE_PALETTE = [
    (20, 25, 50),
    (35, 87, 235),
    (54, 122, 255),
    (34, 211, 238),
    (104, 232, 255),
    (184, 248, 255),
    (255, 255, 255),
    (75, 61, 194),
    (122, 91, 255),
    (17, 24, 39),
]
TROPHY_PALETTE = [
    (31, 25, 74),
    (92, 62, 208),
    (124, 78, 244),
    (163, 130, 255),
    (255, 190, 59),
    (255, 217, 104),
    (255, 241, 181),
    (255, 255, 255),
    (26, 36, 64),
]


def scaled(points: list[tuple[float, float]]) -> list[tuple[int, int]]:
    return [(round(x * SCALE), round(y * SCALE)) for x, y in points]


def star_points(cx: float, cy: float, outer: float, inner: float, phase: float):
    return [
        (
            cx + (outer if index % 2 == 0 else inner)
            * math.cos(phase + index * math.pi / 4),
            cy + (outer if index % 2 == 0 else inner)
            * math.sin(phase + index * math.pi / 4),
        )
        for index in range(8)
    ]


def glow_layer(draw_shape, color: tuple[int, int, int], frame: int) -> Image.Image:
    glow = Image.new("RGBA", (SIZE[0] * SCALE, SIZE[1] * SCALE), (0, 0, 0, 0))
    draw_shape(ImageDraw.Draw(glow), (*color, 120 + round(35 * math.sin(frame * .45))))
    return glow.filter(ImageFilter.GaussianBlur(12 * SCALE))


def make_xp_frame(frame: int) -> Image.Image:
    phase = frame / FRAME_COUNT * math.tau
    bob = math.sin(phase) * 2.2

    def bolt(draw: ImageDraw.ImageDraw, fill):
        shape = [(61, 20 + bob), (34, 73 + bob), (49, 73 + bob),
                 (39, 128 + bob), (78, 63 + bob), (61, 63 + bob)]
        draw.polygon(scaled(shape), fill=fill)

    canvas = Image.new("RGBA", (SIZE[0] * SCALE, SIZE[1] * SCALE), (0, 0, 0, 0))
    canvas.alpha_composite(glow_layer(bolt, (34, 115, 255), frame))
    draw = ImageDraw.Draw(canvas)

    # Small orbiting sparks give the energy symbol a lively, repeatable pulse.
    for index in range(4):
        angle = phase + index * math.pi / 2
        cx = 54 + math.cos(angle) * 43
        cy = 75 + math.sin(angle) * 49
        radius = 3.2 + 1.1 * math.sin(phase * 2 + index)
        alpha = 160 + round(95 * (0.5 + 0.5 * math.sin(phase * 2 + index)))
        points = star_points(cx, cy, radius, radius * .28, phase * .3)
        draw.polygon(scaled(points), fill=(76, 218, 255, alpha))

    bolt(draw, (38, 103, 246, 255))
    draw.polygon(
        scaled([(58, 32 + bob), (42, 69 + bob), (53, 69 + bob),
                (47, 104 + bob), (69, 59 + bob), (57, 59 + bob)]),
        fill=(50, 213, 247, 255),
    )
    draw.line(
        scaled([(58, 38 + bob), (49, 60 + bob)]),
        fill=(202, 251, 255, 235),
        width=2 * SCALE,
    )

    image = canvas.resize(SIZE, Image.Resampling.LANCZOS)
    angle = math.sin(phase) * 2.5
    return image.rotate(angle, resample=Image.Resampling.BICUBIC, center=(54, 75))


def make_trophy_frame(frame: int) -> Image.Image:
    phase = frame / FRAME_COUNT * math.tau
    bob = math.sin(phase) * 1.7

    def cup(draw: ImageDraw.ImageDraw, fill):
        draw.polygon(
            scaled([(30, 31 + bob), (78, 31 + bob), (76, 53 + bob),
                    (70, 68 + bob), (60, 79 + bob), (48, 79 + bob),
                    (38, 68 + bob), (32, 53 + bob)]),
            fill=fill,
        )

    canvas = Image.new("RGBA", (SIZE[0] * SCALE, SIZE[1] * SCALE), (0, 0, 0, 0))
    canvas.alpha_composite(glow_layer(cup, (129, 86, 255), frame))
    draw = ImageDraw.Draw(canvas)

    # Handles sit behind the bowl and share the same violet outline.
    draw.line(scaled([(33, 43 + bob), (22, 43 + bob), (22, 54 + bob),
                      (27, 64 + bob), (40, 68 + bob)]),
              fill=(104, 70, 222, 255), width=7 * SCALE, joint="curve")
    draw.line(scaled([(75, 43 + bob), (86, 43 + bob), (86, 54 + bob),
                      (81, 64 + bob), (68, 68 + bob)]),
              fill=(104, 70, 222, 255), width=7 * SCALE, joint="curve")

    cup(draw, (107, 73, 223, 255))
    draw.polygon(
        scaled([(39, 39 + bob), (69, 39 + bob), (67, 52 + bob),
                (62, 62 + bob), (54, 69 + bob), (46, 62 + bob),
                (41, 52 + bob)]),
        fill=(255, 193, 66, 255),
    )
    draw.line(scaled([(46, 81 + bob), (62, 81 + bob), (62, 101 + bob),
                      (46, 101 + bob)]), fill=(124, 87, 233, 255),
              width=8 * SCALE, joint="curve")
    draw.rounded_rectangle(
        (35 * SCALE, round((99 + bob) * SCALE), 73 * SCALE,
         round((110 + bob) * SCALE)),
        radius=4 * SCALE,
        fill=(91, 65, 204, 255),
    )
    draw.rounded_rectangle(
        (29 * SCALE, round((109 + bob) * SCALE), 79 * SCALE,
         round((120 + bob) * SCALE)),
        radius=5 * SCALE,
        fill=(124, 87, 233, 255),
    )
    draw.line(scaled([(44, 44 + bob), (48, 58 + bob)]),
              fill=(255, 239, 179, 235), width=2 * SCALE)

    for index, (cx, cy) in enumerate([(19, 30), (88, 29), (18, 93), (91, 87)]):
        pulse = .5 + .5 * math.sin(phase * 2 + index * 1.5)
        radius = 2 + pulse * 2.2
        alpha = 100 + round(155 * pulse)
        points = star_points(cx, cy, radius, radius * .3, phase * .2)
        draw.polygon(scaled(points), fill=(255, 213, 108, alpha))

    image = canvas.resize(SIZE, Image.Resampling.LANCZOS)
    angle = math.sin(phase) * 2.2
    return image.rotate(angle, resample=Image.Resampling.BICUBIC, center=(54, 75))


def to_gif(frames: list[Image.Image], durations: list[int], colors) -> None:
    palette = Image.new("P", (1, 1))
    entries = list(colors) + [(0, 0, 0)] * (255 - len(colors)) + [(0, 0, 0)]
    palette.putpalette([component for color in entries for component in color])
    converted = []
    for frame in frames:
        alpha = frame.getchannel("A")
        indexed = frame.convert("RGB").quantize(palette=palette, dither=Image.Dither.NONE)
        transparent = alpha.point(lambda value: 255 if value < 8 else 0)
        indexed.paste(255, mask=transparent)
        indexed.putpalette(palette.getpalette())
        converted.append(indexed)
    output = ANIMATED / ("XP.gif" if colors is BLUE_PALETTE else "Trophy.gif")
    converted[0].save(
        output,
        save_all=True,
        append_images=converted[1:],
        duration=durations,
        loop=0,
        transparency=255,
        disposal=2,
        optimize=False,
    )


def main() -> None:
    reference = Image.open(ANIMATED / "Fire.gif")
    durations = []
    for index in range(reference.n_frames):
        reference.seek(index)
        durations.append(reference.info.get("duration", 40))
    to_gif([make_xp_frame(i) for i in range(FRAME_COUNT)], durations, BLUE_PALETTE)
    to_gif([make_trophy_frame(i) for i in range(FRAME_COUNT)], durations, TROPHY_PALETTE)


if __name__ == "__main__":
    main()
