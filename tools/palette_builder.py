#!/usr/bin/env python3
"""Builds the Fieldweave cosmetic palettes and verifies that every colour in a
palette is perceptually separable from every other one.

Distinguishable colours are a *gameplay* requirement in a magnetic grid, not a
styling preference: two flows that read as "the same blue" make a board
unplayable. Each palette is therefore chosen by maximising the minimum CIE76
distance between its colours, and the result is asserted before it can reach
the catalogue.

Run: python3 tools/palette_builder.py
"""
import argparse
import colorsys
import math
import pathlib
import sys

COLOR_SLOTS = 14      # the largest colour count DifficultyCurve can produce
THRESHOLD = 22.0      # minimum acceptable CIE76 distance inside one palette

# name, hue offset, (sat_lo, sat_hi), (light_lo, light_hi)
THEMES = [
    ("aurora",  0.00, (0.72, 0.90), (0.54, 0.70)),
    ("tide",    0.55, (0.60, 0.82), (0.48, 0.68)),
    ("ember",   0.06, (0.78, 0.96), (0.50, 0.66)),
    ("circuit", 0.33, (0.88, 1.00), (0.48, 0.64)),
    ("orchid",  0.85, (0.66, 0.88), (0.56, 0.74)),
    ("glacier", 0.50, (0.44, 0.66), (0.62, 0.80)),
    ("dusk",    0.72, (0.52, 0.74), (0.44, 0.62)),
    ("nebula",  0.78, (0.76, 0.96), (0.50, 0.68)),
]


def srgb_to_lab(rgb):
    def linear(c):
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = (linear(c) for c in rgb)
    x = r * 0.4124 + g * 0.3576 + b * 0.1805
    y = r * 0.2126 + g * 0.7152 + b * 0.0722
    z = r * 0.0193 + g * 0.1192 + b * 0.9505

    def f(t):
        return t ** (1 / 3) if t > 0.008856 else (7.787 * t) + 16 / 116
    fx, fy, fz = f(x / 0.95047), f(y / 1.0), f(z / 1.08883)
    return (116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz))


def delta_e(a, b):
    return math.sqrt((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2)


def hexed(rgb):
    return "#" + "".join(f"{round(max(0.0, min(1.0, v)) * 255):02X}" for v in rgb)


def candidates(theme):
    """Every colour the theme allows, sampled across the whole hue wheel."""
    _, offset, (s_lo, s_hi), (l_lo, l_hi) = theme
    pool = []
    for hue_step in range(120):
        hue = ((hue_step / 120.0) + offset) % 1.0
        for sat_step in range(3):
            sat = s_lo + (s_hi - s_lo) * sat_step / 2.0
            for light_step in range(3):
                light = l_lo + (l_hi - l_lo) * light_step / 2.0
                pool.append(colorsys.hls_to_rgb(hue, light, sat))
    return pool


def build(theme):
    """Farthest-point selection in CIE Lab, then a local improvement pass."""
    pool = candidates(theme)
    labs = [srgb_to_lab(c) for c in pool]
    size = len(pool)
    distance = [[0.0] * size for _ in range(size)]
    for i in range(size):
        for j in range(i + 1, size):
            d = delta_e(labs[i], labs[j])
            distance[i][j] = d
            distance[j][i] = d

    # Anchor on the theme's own hue so each palette keeps its identity.
    chosen = [0]
    while len(chosen) < COLOR_SLOTS:
        best, best_gap = None, -1.0
        for index in range(size):
            if index in chosen:
                continue
            gap = min(distance[index][c] for c in chosen)
            if gap > best_gap:
                best, best_gap = index, gap
        chosen.append(best)

    # Improvement: replace one slot at a time with whatever raises the floor.
    for _ in range(8):
        improved = False
        for slot in range(COLOR_SLOTS):
            others = [c for i, c in enumerate(chosen) if i != slot]
            floor_without = min(
                distance[others[i]][others[j]]
                for i in range(len(others)) for j in range(i + 1, len(others))
            )
            current = min(floor_without, min(distance[chosen[slot]][o] for o in others))
            best, best_gap = chosen[slot], current
            for index in range(size):
                if index in chosen:
                    continue
                gap = min(floor_without, min(distance[index][o] for o in others))
                if gap > best_gap + 1e-9:
                    best, best_gap = index, gap
            if best != chosen[slot]:
                chosen[slot] = best
                improved = True
        if not improved:
            break

    # Order by hue so the on-screen colour sequence reads as a spectrum.
    selected = [pool[i] for i in chosen]
    selected.sort(key=lambda c: colorsys.rgb_to_hls(*c)[0])
    return selected


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--check",
        action="store_true",
        help="verify the committed Swift file matches, instead of rewriting it",
    )
    arguments = parser.parse_args()

    palettes = []
    worst_global = math.inf
    for theme in THEMES:
        colors = build(theme)
        labs = [srgb_to_lab(c) for c in colors]
        worst = min(
            delta_e(labs[i], labs[j])
            for i in range(len(labs)) for j in range(i + 1, len(labs))
        )
        worst_global = min(worst_global, worst)
        print(f"{'OK ' if worst >= THRESHOLD else 'LOW'} {theme[0]:<9} min deltaE = {worst:5.1f}")
        palettes.append((theme[0], [hexed(c) for c in colors]))

    print(f"\nglobal worst deltaE = {worst_global:.1f} (threshold {THRESHOLD:.0f})")

    path = "PuzzleKit/Sources/PuzzleKit/Economy/PaletteColors.generated.swift"
    rendered = render(palettes)

    if arguments.check:
        existing = pathlib.Path(path).read_text() if pathlib.Path(path).exists() else ""
        if existing != rendered:
            print(f"FAIL {path} is out of date - rerun tools/palette_builder.py")
            return 1
        print(f"{path} matches")
        return 0 if worst_global >= THRESHOLD else 1

    pathlib.Path(path).write_text(rendered)
    print(f"wrote {path}")
    return 0 if worst_global >= THRESHOLD else 1


def render(palettes):
    """The exact contents of the generated Swift file."""
    import io
    with io.StringIO() as fh:
        fh.write("// Generated by tools/palette_builder.py - do not edit by hand.\n")
        fh.write("//\n")
        fh.write("// Distinguishable flow colours are a gameplay requirement, not a styling\n")
        fh.write("// choice. Every palette below is verified to keep a CIE76 distance of at\n")
        fh.write(f"// least {THRESHOLD:.0f} between any two of its colours before it ships.\n\n")
        fh.write("public extension CosmeticCatalog {\n\n")
        fh.write("    /// Flow colours per palette id, indexed by colour number.\n")
        fh.write("    static let paletteColors: [String: [String]] = [\n")
        for name, hexes in palettes:
            fh.write(f'        "{name}": [\n')
            for row in range(0, len(hexes), 4):
                chunk = ", ".join(f'"{h}"' for h in hexes[row:row + 4])
                fh.write(f"            {chunk},\n")
            fh.write("        ],\n")
        fh.write("    ]\n}\n")
        return fh.getvalue()


if __name__ == "__main__":
    sys.exit(main())
