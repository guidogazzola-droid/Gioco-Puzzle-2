#!/usr/bin/env python3
"""Draws the Prism Flow app icon from the game's own visual language.

The icon is three flows finishing a knot on a dark board: the same round caps,
the same endpoint nodes and the same aurora palette the game draws with, so the
Home Screen and the first frame of the game look like the same product.

Written with zlib and nothing else - the icon is a build input, not something
that should need an image toolchain to reproduce. iOS icons must be fully
opaque, so this writes RGB (PNG colour type 2) with no alpha channel at all.

Run: python3 tools/make_app_icon.py
"""
import math
import pathlib
import struct
import sys
import zlib

SIZE = 1024
OUTPUT = pathlib.Path("PrismFlow/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png")

BACKGROUND_TOP = (0x1A, 0x22, 0x33)
BACKGROUND_BOTTOM = (0x0A, 0x0E, 0x18)
BOARD = (0x11, 0x17, 0x22)

# Three flows on a 5x5 board, drawn in aurora colours.
FLOWS = [
    ((0xF3, 0x7F, 0x20), [(0, 4), (0, 3), (0, 2), (1, 2), (2, 2), (2, 3), (2, 4)]),
    ((0x20, 0xF3, 0xB4), [(4, 0), (3, 0), (2, 0), (2, 1), (1, 1), (0, 1), (0, 0)]),
    ((0x20, 0x7F, 0xF3), [(4, 4), (4, 3), (3, 3), (3, 2), (4, 2), (4, 1), (3, 1)]),
]

GRID = 5
MARGIN = SIZE * 0.14
CELL = (SIZE - MARGIN * 2) / GRID
STROKE = CELL * 0.40
NODE = CELL * 0.30


def blend(base, color, alpha):
    return tuple(round(base[i] + (color[i] - base[i]) * alpha) for i in range(3))


class Canvas:
    def __init__(self, size):
        self.size = size
        self.pixels = bytearray(size * size * 3)

    def fill_gradient(self, top, bottom):
        for y in range(self.size):
            t = y / (self.size - 1)
            row = tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
            offset = y * self.size * 3
            self.pixels[offset:offset + self.size * 3] = bytes(row) * self.size

    def get(self, x, y):
        i = (y * self.size + x) * 3
        return (self.pixels[i], self.pixels[i + 1], self.pixels[i + 2])

    def put(self, x, y, color):
        i = (y * self.size + x) * 3
        self.pixels[i], self.pixels[i + 1], self.pixels[i + 2] = color

    def rounded_rect(self, x0, y0, x1, y1, radius, color, alpha=1.0):
        """Anti-aliased rounded rectangle via a signed distance field."""
        lo_x, hi_x = max(0, int(x0 - 2)), min(self.size, int(x1 + 3))
        lo_y, hi_y = max(0, int(y0 - 2)), min(self.size, int(y1 + 3))
        cx0, cy0, cx1, cy1 = x0 + radius, y0 + radius, x1 - radius, y1 - radius
        for py in range(lo_y, hi_y):
            fy = py + 0.5
            for px in range(lo_x, hi_x):
                fx = px + 0.5
                dx = max(cx0 - fx, 0.0, fx - cx1)
                dy = max(cy0 - fy, 0.0, fy - cy1)
                distance = math.hypot(dx, dy) - radius
                coverage = min(1.0, max(0.0, 0.5 - distance))
                if coverage > 0:
                    self.put(px, py, blend(self.get(px, py), color, coverage * alpha))

    def capsule(self, ax, ay, bx, by, half_width, color, alpha=1.0):
        """Anti-aliased round-capped segment - the game's trail, exactly."""
        lo_x = max(0, int(min(ax, bx) - half_width - 2))
        hi_x = min(self.size, int(max(ax, bx) + half_width + 3))
        lo_y = max(0, int(min(ay, by) - half_width - 2))
        hi_y = min(self.size, int(max(ay, by) + half_width + 3))
        vx, vy = bx - ax, by - ay
        length_squared = vx * vx + vy * vy
        for py in range(lo_y, hi_y):
            fy = py + 0.5
            for px in range(lo_x, hi_x):
                fx = px + 0.5
                if length_squared == 0:
                    distance = math.hypot(fx - ax, fy - ay)
                else:
                    t = ((fx - ax) * vx + (fy - ay) * vy) / length_squared
                    t = min(1.0, max(0.0, t))
                    distance = math.hypot(fx - ax - t * vx, fy - ay - t * vy)
                coverage = min(1.0, max(0.0, half_width + 0.5 - distance))
                if coverage > 0:
                    self.put(px, py, blend(self.get(px, py), color, coverage * alpha))

    def disc(self, cx, cy, radius, color, alpha=1.0):
        self.capsule(cx, cy, cx, cy, radius, color, alpha)

    def write_png(self, path):
        raw = bytearray()
        stride = self.size * 3
        for y in range(self.size):
            raw.append(0)                                  # filter type: none
            raw.extend(self.pixels[y * stride:(y + 1) * stride])

        def chunk(tag, payload):
            body = tag + payload
            return struct.pack(">I", len(payload)) + body + struct.pack(">I", zlib.crc32(body))

        header = struct.pack(">IIBBBBB", self.size, self.size, 8, 2, 0, 0, 0)
        png = (b"\x89PNG\r\n\x1a\n"
               + chunk(b"IHDR", header)
               + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
               + chunk(b"IEND", b""))
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(png)
        return len(png)


def center(cell):
    x, y = cell
    return (MARGIN + (x + 0.5) * CELL, MARGIN + (y + 0.5) * CELL)


def main():
    canvas = Canvas(SIZE)
    canvas.fill_gradient(BACKGROUND_TOP, BACKGROUND_BOTTOM)

    board = MARGIN - CELL * 0.22
    canvas.rounded_rect(board, board, SIZE - board, SIZE - board, CELL * 0.42, BOARD, 0.85)

    for color, path in FLOWS:
        points = [center(cell) for cell in path]
        # Halo first, then the trail, matching the in-game glow trail style.
        for (ax, ay), (bx, by) in zip(points, points[1:]):
            canvas.capsule(ax, ay, bx, by, STROKE * 0.5 + CELL * 0.16, color, 0.22)
        for (ax, ay), (bx, by) in zip(points, points[1:]):
            canvas.capsule(ax, ay, bx, by, STROKE * 0.5, color)
        for cx, cy in (points[0], points[-1]):
            canvas.disc(cx, cy, NODE * 1.34, (0, 0, 0), 0.28)
            canvas.disc(cx, cy, NODE, color)

    written = canvas.write_png(OUTPUT)
    print(f"wrote {OUTPUT} ({written / 1024:.0f} KB, {SIZE}x{SIZE}, RGB no alpha)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
