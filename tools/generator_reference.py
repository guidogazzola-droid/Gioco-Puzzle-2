#!/usr/bin/env python3
"""
Reference implementation + validation harness for the Fieldweave procedural
level generator.

This file is the executable specification that `PuzzleKit/Sources/PuzzleKit/
Generation/LevelGenerator.swift` is a 1:1 port of. It exists so the generation
algorithm can be validated (solvability, difficulty curve, determinism) without
an Xcode toolchain.

Run:  python3 tools/generator_reference.py            # full validation suite
      python3 tools/generator_reference.py --show 42  # print level 42
"""

from __future__ import annotations

import argparse
import sys
from dataclasses import dataclass, field

MASK64 = (1 << 64) - 1

# ---------------------------------------------------------------------------
# Deterministic RNG (SplitMix64) - identical output to the Swift port.
# ---------------------------------------------------------------------------


class SplitMix64:
    def __init__(self, seed: int) -> None:
        self.state = seed & MASK64

    def next_u64(self) -> int:
        self.state = (self.state + 0x9E3779B97F4A7C15) & MASK64
        z = self.state
        z = ((z ^ (z >> 30)) * 0xBF58476D1CE4E5B9) & MASK64
        z = ((z ^ (z >> 27)) * 0x94D049BB133111EB) & MASK64
        return (z ^ (z >> 31)) & MASK64

    def int_below(self, bound: int) -> int:
        """Unbiased [0, bound) using Lemire's multiply-shift rejection."""
        if bound <= 1:
            return 0
        threshold = (MASK64 + 1 - bound) % bound
        while True:
            r = self.next_u64()
            if r >= threshold:
                return r % bound

    def pick(self, items: list):
        return items[self.int_below(len(items))]

    def shuffled(self, items: list) -> list:
        out = list(items)
        for i in range(len(out) - 1, 0, -1):
            j = self.int_below(i + 1)
            out[i], out[j] = out[j], out[i]
        return out

    def chance(self, percent: int) -> bool:
        return self.int_below(100) < percent


# ---------------------------------------------------------------------------
# Difficulty curve
# ---------------------------------------------------------------------------

FREE_TRACK = "free"
PRO_TRACK = "pro"


@dataclass(frozen=True)
class LevelParameters:
    width: int
    height: int
    colors: int
    blocked: int
    is_boss: bool
    is_breather: bool

    @property
    def playable(self) -> int:
        return self.width * self.height - self.blocked


# A designed stage table beats a linear ramp: it lets the curve breathe at the
# points where hybrid-casual retention data says players churn (L3-L10, L30).
# (minLevel, side, colors)
FREE_STAGES = [
    (1, 5, 3), (7, 5, 4), (15, 6, 4), (25, 6, 5), (37, 7, 5),
    (51, 7, 6), (67, 8, 6), (85, 8, 7), (105, 9, 7), (130, 9, 8),
]
PRO_STAGES = [
    (1, 7, 5), (9, 8, 6), (19, 8, 7), (31, 9, 8), (45, 10, 9),
    (61, 10, 10), (79, 11, 11), (99, 12, 12), (121, 12, 13),
]

# Board silhouette cycle, applied on top of the stage table so that late levels
# keep changing shape after the size curve has plateaued. (dw, dh)
SHAPE_CYCLE = [(0, 0), (0, -1), (0, 0), (-1, 0), (1, -1), (0, 0)]


def _stage(level: int, stages: list) -> tuple[int, int]:
    side, colors = stages[0][1], stages[0][2]
    for min_level, s, c in stages:
        if level >= min_level:
            side, colors = s, c
    return side, colors


def parameters(level: int, track: str = FREE_TRACK) -> LevelParameters:
    """level is 1-based."""
    is_boss = level % 10 == 0
    # Every 7th level (that is not a boss) is an easier "breather": the
    # hybrid-casual pacing pattern that stops failure rates from stacking.
    is_breather = (level % 7 == 0) and not is_boss

    if track == PRO_TRACK:
        side, colors = _stage(level, PRO_STAGES)
        blocked_pct = min(10, max(0, (level - 15) // 8))
    else:
        side, colors = _stage(level, FREE_STAGES)
        blocked_pct = 0  # walls stay a Pro-track differentiator

    dw, dh = SHAPE_CYCLE[level % len(SHAPE_CYCLE)]
    width = max(5, side + dw)
    height = max(5, side + dh)

    if is_boss:
        width = min(width + 1, 13)
        height = min(height + 1, 13)
        colors += 1
    if is_breather:
        colors = max(3, colors - 2)
        blocked_pct = 0

    cells = width * height
    blocked = (cells * blocked_pct) // 100
    blocked = min(blocked, max(0, cells // 6))

    playable = cells - blocked
    # A colour needs at least 2 cells; keep at least 2 cells of slack.
    colors = max(3, min(colors, (playable // 2) - 1))
    return LevelParameters(width, height, colors, blocked, is_boss, is_breather)


def target_twistiness(level: int, track: str) -> float:
    """Turns-per-playable-cell the generator aims for. Low = readable tutorial
    boards, high = knotted late-game boards."""
    base = 0.18 if track == FREE_TRACK else 0.34
    cap = 0.52 if track == FREE_TRACK else 0.62
    growth = min(1.0, max(0, level - 1) / 60.0)
    return base + (cap - base) * growth


# ---------------------------------------------------------------------------
# Grid helpers
# ---------------------------------------------------------------------------


def neighbours(cell: tuple[int, int], width: int, height: int) -> list[tuple[int, int]]:
    x, y = cell
    out = []
    if y > 0:
        out.append((x, y - 1))
    if x > 0:
        out.append((x - 1, y))
    if x + 1 < width:
        out.append((x + 1, y))
    if y + 1 < height:
        out.append((x, y + 1))
    return out


def is_connected(cells: set[tuple[int, int]], width: int, height: int) -> bool:
    if not cells:
        return True
    start = next(iter(sorted(cells)))
    seen = {start}
    stack = [start]
    while stack:
        cur = stack.pop()
        for n in neighbours(cur, width, height):
            if n in cells and n not in seen:
                seen.add(n)
                stack.append(n)
    return len(seen) == len(cells)


# ---------------------------------------------------------------------------
# Generation
# ---------------------------------------------------------------------------


@dataclass
class Blueprint:
    width: int
    height: int
    blocked: set = field(default_factory=set)
    solution: list = field(default_factory=list)  # list[list[cell]] one per colour
    seed: int = 0
    level: int = 0
    track: str = FREE_TRACK

    @property
    def endpoints(self):
        return [(p[0], p[-1]) for p in self.solution]

    @property
    def par_moves(self) -> int:
        return len(self.solution)

    @property
    def turns(self) -> int:
        total = 0
        for path in self.solution:
            for i in range(1, len(path) - 1):
                ax, ay = path[i - 1]
                bx, by = path[i + 1]
                if ax != bx and ay != by:
                    total += 1
        return total


def _pick_blocked(rng: SplitMix64, width: int, height: int, count: int) -> set | None:
    """Blocked cells are carved from the border inward so the remaining board
    stays orthogonally connected (checked explicitly)."""
    if count <= 0:
        return set()
    all_cells = [(x, y) for y in range(height) for x in range(width)]
    blocked: set = set()
    candidates = rng.shuffled(all_cells)
    for cell in candidates:
        if len(blocked) == count:
            break
        trial = blocked | {cell}
        remaining = {c for c in all_cells if c not in trial}
        if len(remaining) < 6:
            continue
        if is_connected(remaining, width, height):
            blocked = trial
    return blocked if len(blocked) == count else None


def _partition(rng: SplitMix64, width: int, height: int, blocked: set,
               max_length: int) -> list | None:
    """Cover every free cell with vertex-disjoint simple paths.

    Paths grow bidirectionally with a Warnsdorff-style bias (prefer the
    neighbour with the fewest onward options), which is what keeps the board
    from fragmenting into single cells. `max_length` stops any one colour from
    swallowing the board - balanced path lengths are what make a Flow board
    readable.
    """
    free = {(x, y) for y in range(height) for x in range(width)} - blocked
    paths: list[list] = []
    guard = 0
    while free:
        guard += 1
        if guard > width * height + 8:
            return None
        # Start from the most constrained free cell (fewest free neighbours).
        ordered = rng.shuffled(sorted(free))
        start = min(ordered, key=lambda c: sum(1 for n in neighbours(c, width, height) if n in free))
        free.discard(start)
        path = [start]
        for head_is_tail in (True, False):
            while len(path) < max_length:
                head = path[-1] if head_is_tail else path[0]
                options = [n for n in neighbours(head, width, height) if n in free]
                if not options:
                    break
                if rng.chance(75):
                    step = min(
                        options,
                        key=lambda c: sum(1 for n in neighbours(c, width, height) if n in free),
                    )
                else:
                    step = rng.pick(rng.shuffled(options))
                free.discard(step)
                if head_is_tail:
                    path.append(step)
                else:
                    path.insert(0, step)
        paths.append(path)
    return paths


def _absorb_singletons(rng: SplitMix64, paths: list, width: int, height: int) -> list | None:
    """Remove every length-1 path by grafting it onto a neighbouring path."""
    for _ in range(256):
        index = next((i for i, p in enumerate(paths) if len(p) == 1), None)
        if index is None:
            return paths
        cell = paths[index][0]
        owner = {}
        for pi, path in enumerate(paths):
            for ci, c in enumerate(path):
                owner[c] = (pi, ci)
        options = [n for n in neighbours(cell, width, height) if n in owner and owner[n][0] != index]
        if not options:
            return None
        # Prefer grafting onto an endpoint: that merges two paths without
        # creating a new one.
        endpoint_options = [n for n in options if owner[n][1] in (0, len(paths[owner[n][0]]) - 1)]
        target = rng.pick(rng.shuffled(endpoint_options or options))
        pi, ci = owner[target]
        host = paths[pi]
        if ci == 0:
            paths[pi] = [cell] + host
            paths.pop(index)
        elif ci == len(host) - 1:
            paths[pi] = host + [cell]
            paths.pop(index)
        else:
            head, tail = host[:ci], host[ci + 1:]
            paths[pi] = head
            paths.append(tail)
            paths[index] = [target, cell]
    return None


def _adjacent(a: tuple[int, int], b: tuple[int, int]) -> bool:
    return abs(a[0] - b[0]) + abs(a[1] - b[1]) == 1


def _join(a: list, b: list) -> list | None:
    """Concatenate two vertex-disjoint simple paths whose endpoints touch."""
    if _adjacent(a[-1], b[0]):
        return a + b
    if _adjacent(a[-1], b[-1]):
        return a + b[::-1]
    if _adjacent(a[0], b[0]):
        return a[::-1] + b
    if _adjacent(a[0], b[-1]):
        return b + a
    return None


def _merge_shortest(rng: SplitMix64, paths: list) -> bool:
    """Merge the cheapest mergeable pair (shortest combined length wins, so the
    colour lengths stay even). Returns False when nothing can be merged."""
    best = None
    best_cost = None
    for i in range(len(paths)):
        for j in range(i + 1, len(paths)):
            joined = _join(paths[i], paths[j])
            if joined is None:
                continue
            cost = len(joined)
            if best_cost is None or cost < best_cost:
                best, best_cost = (i, j, joined), cost
    if best is None:
        return False
    i, j, joined = best
    paths[i] = joined
    paths.pop(j)
    return True


def _split_longest(rng: SplitMix64, paths: list) -> bool:
    """Split the longest path near its middle. Returns False if none qualify."""
    splittable = [i for i, p in enumerate(paths) if len(p) >= 4]
    if not splittable:
        return False
    longest = max(splittable, key=lambda i: (len(paths[i]), -i))
    path = paths[longest]
    mid = len(path) // 2
    jitter = rng.int_below(3) - 1
    cut = min(max(2, mid + jitter), len(path) - 2)
    paths[longest] = path[:cut]
    paths.append(path[cut:])
    return True


def _retarget_colors(rng: SplitMix64, paths: list, target: int) -> list | None:
    """Merge or split paths until exactly `target` of them remain, then even
    out the lengths at a constant colour count.

    Merging two vertex-disjoint simple paths whose endpoints touch always
    yields a simple path, and splitting one always yields two simple paths, so
    the covering stays valid throughout.
    """
    paths = [list(p) for p in paths]
    guard = 0
    while len(paths) > target:
        guard += 1
        if guard > 512 or not _merge_shortest(rng, paths):
            return None
    while len(paths) < target:
        guard += 1
        if guard > 512 or not _split_longest(rng, paths):
            return None

    # Rebalance at a fixed colour count: split the hog, re-absorb the runt.
    for _ in range(24):
        longest = max(len(p) for p in paths)
        shortest = min(len(p) for p in paths)
        if longest <= max(4, shortest * 3):
            break
        snapshot = [list(p) for p in paths]
        if not _split_longest(rng, paths) or not _merge_shortest(rng, paths):
            paths = snapshot
            break
        if len(paths) != target or max(len(p) for p in paths) >= longest:
            paths = snapshot
            break
    return paths if all(len(p) >= 2 for p in paths) else None


CANDIDATES = 12
MAX_ATTEMPTS = 96


def _quality(bp: Blueprint, params: LevelParameters, target: float) -> float:
    """Lower is better. Scores how close a candidate is to the intended feel."""
    ratio = bp.turns / max(1, params.playable)
    score = abs(ratio - target) * 4.0
    # Too many two-cell colours makes a board read as filler.
    trivial = sum(1 for p in bp.solution if len(p) <= 2)
    allowance = max(1, len(bp.solution) // 3)
    if trivial > allowance:
        score += 0.35 * (trivial - allowance)
    # One colour swallowing the board is the single worst failure mode.
    lengths = [len(p) for p in bp.solution]
    average = params.playable / max(1, len(lengths))
    score += max(0.0, (max(lengths) / average) - 1.8) * 0.9
    return score


def _attempt(level: int, track: str, params: LevelParameters, seed: int) -> Blueprint | None:
    rng = SplitMix64(seed)
    blocked = _pick_blocked(rng, params.width, params.height, params.blocked)
    if blocked is None:
        return None
    cap = max(3, (params.playable * 3) // (2 * max(1, params.colors)))
    paths = _partition(rng, params.width, params.height, blocked, cap)
    if paths is None:
        return None
    paths = _absorb_singletons(rng, paths, params.width, params.height)
    if paths is None:
        return None
    paths = _retarget_colors(rng, paths, params.colors)
    if paths is None:
        return None
    if any(len(p) < 2 for p in paths):
        return None
    bp = Blueprint(params.width, params.height, blocked, paths, seed, level, track)
    return bp if validate(bp) else None


def seed(level: int, track: str, salt: int, attempt: int) -> int:
    track_salt = 0x5052_4F00 if track == PRO_TRACK else 0x4652_4545
    return (level * 0x9E3779B97F4A7C15 + track_salt
            + salt * 0x0100_0001 + attempt * 0x2545_F491) & MASK64


def generate(level: int, track: str = FREE_TRACK, salt: int = 0) -> Blueprint:
    """Deterministic: (level, track, salt) always yields the same board."""
    params = parameters(level, track)
    target = target_twistiness(level, track)
    best: Blueprint | None = None
    best_score = float("inf")
    found = 0
    for attempt in range(MAX_ATTEMPTS):
        bp = _attempt(level, track, params, seed(level, track, salt, attempt))
        if bp is None:
            continue
        found += 1
        score = _quality(bp, params, target)
        if score < best_score:
            best, best_score = bp, score
        if found >= CANDIDATES:
            break
    if best is None:
        raise RuntimeError(f"generation failed for level {level} track {track}")
    return best


# ---------------------------------------------------------------------------
# Validation - the invariants the Swift port asserts in its tests
# ---------------------------------------------------------------------------


def validate(bp: Blueprint) -> bool:
    cells = {(x, y) for y in range(bp.height) for x in range(bp.width)}
    free = cells - set(bp.blocked)
    seen = set()
    for path in bp.solution:
        if len(path) < 2:
            return False
        if len(set(path)) != len(path):
            return False           # a colour may not revisit a cell
        for c in path:
            if c not in free:
                return False       # never routed through a wall
            if c in seen:
                return False       # colours may not overlap
            seen.add(c)
        for a, b in zip(path, path[1:]):
            if not _adjacent(a, b):
                return False       # steps are orthogonal
    return seen == free            # every free cell is covered


# ---------------------------------------------------------------------------
# Harness
# ---------------------------------------------------------------------------


def render(bp: Blueprint) -> str:
    glyphs = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    grid = [["." for _ in range(bp.width)] for _ in range(bp.height)]
    for c in bp.blocked:
        grid[c[1]][c[0]] = "#"
    for i, path in enumerate(bp.solution):
        for j, c in enumerate(path):
            g = glyphs[i % len(glyphs)]
            grid[c[1]][c[0]] = g if j in (0, len(path) - 1) else g.lower()
    return "\n".join(" ".join(row) for row in grid)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--show", type=int, default=None)
    ap.add_argument("--track", default=FREE_TRACK, choices=[FREE_TRACK, PRO_TRACK])
    ap.add_argument("--levels", type=int, default=400)
    args = ap.parse_args()

    if args.show is not None:
        bp = generate(args.show, args.track)
        print(f"Level {args.show} [{args.track}] {bp.width}x{bp.height} "
              f"colors={len(bp.solution)} blocked={len(bp.blocked)} "
              f"par={bp.par_moves} turns={bp.turns} seed={bp.seed}")
        print(render(bp))
        return 0

    failures = 0
    stats = []
    for track in (FREE_TRACK, PRO_TRACK):
        for level in range(1, args.levels + 1):
            try:
                bp = generate(level, track)
            except RuntimeError as exc:
                print(f"FAIL  {exc}")
                failures += 1
                continue
            if not validate(bp):
                print(f"FAIL  invalid blueprint level={level} track={track}")
                failures += 1
                continue
            p = parameters(level, track)
            if len(bp.solution) != p.colors:
                print(f"FAIL  colour mismatch level={level} track={track} "
                      f"{len(bp.solution)} != {p.colors}")
                failures += 1
            stats.append((track, level, bp))

    # Determinism: the same level must produce byte-identical output.
    for track in (FREE_TRACK, PRO_TRACK):
        for level in (1, 7, 10, 42, 137, 400):
            a, b = generate(level, track), generate(level, track)
            if a.solution != b.solution or a.blocked != b.blocked:
                print(f"FAIL  non-deterministic level={level} track={track}")
                failures += 1

    print(f"validated {len(stats)} levels across 2 tracks - failures: {failures}")
    for track in (FREE_TRACK, PRO_TRACK):
        rows = [s for s in stats if s[0] == track]
        print(f"\n  {track.upper()} track")
        print(f"  {'level':>6} {'board':>8} {'colors':>7} {'walls':>6} {'par':>4} {'turns':>6}")
        for _, level, bp in rows:
            if level in (1, 5, 10, 25, 50, 100, 200, 300, 400):
                print(f"  {level:>6} {f'{bp.width}x{bp.height}':>8} {len(bp.solution):>7} "
                      f"{len(bp.blocked):>6} {bp.par_moves:>4} {bp.turns:>6}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
