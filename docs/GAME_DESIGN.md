# Game design

## The mechanic

A field is a network of matching-colour endpoint pairs wrapped around a freely
rotatable cube. Start from either endpoint and continue around cube edges until
the two matching colours meet. Two filaments can never share a tile. The cube
is solved when **every matching pair is connected**; unused surface tiles are
valid and do not affect completion.

A route disappearing over an edge still occupies space on the neighbouring
face, so the player must remember and inspect the whole object rather than solve
six independent flat boards. From level 91, two-port rotors add a second rule:
tap one to turn it clockwise, because a closed port physically rejects a trail.

Interaction rules, all implemented in `CubePuzzleEngine` and unit-tested:

| Action | Result |
|---|---|
| Grab either matching endpoint | Restarts that colour from the selected end |
| Tap a rotor (level 91+) | Turns its two open ports clockwise and spends one action |
| Enter a closed rotor port | Rejected with no board mutation |
| Enter another circuit's rotor | Rejected — rotors are circuit-specific |
| Grab a cell mid-trail | Rewinds the colour to that cell and continues |
| Drag back one cell | Rewinds one step |
| Drag onto another colour's trail | Rejected with no board mutation |
| Drag onto another colour's endpoint | Rejected — endpoints are never passable |
| Drag onto a wall | Rejected |
| Reach the matching endpoint | The colour locks |
| Swipe from an empty tile | Rotates the cube freely |
| Lift, rotate, resume at a loose end | Continues the same scored action |

A fast drag is interpolated through the shortest valid surface route. At a seam
the topology maps face-local coordinates exactly and reversibly, so a trail
bends around an edge rather than teleporting through the cube.

## Generation

Levels are generated, never authored. `CubeLevelGenerator` runs these steps:

1. **Surface.** The difficulty curve activates two to six faces at 3×3, 4×4 or
   5×5 tiles per face. `CubeTopology` supplies the four neighbours of every tile,
   including exact folds across all twelve edges.
2. **Walls.** On the Pro track only, wall tiles are carved one at a time, each
   checked to keep the remaining surface graph connected.
3. **Partition.** Every free tile is covered by vertex-disjoint simple paths.
   Paths grow from *both* ends with a Warnsdorff-style bias — step onto the
   neighbour with the fewest onward options — which is what stops the board
   fragmenting into stranded single cells. A length cap of 1.5x the average
   stops any one colour swallowing the board.
4. **Repair.** Any length-1 path is grafted onto a neighbour. Grafting onto an
   endpoint merges two paths; grafting mid-path splits the host. Both keep the
   covering valid, so a singleton is always repairable.
5. **Circuit count.** Paths are merged (shortest pair first, which keeps lengths
   even) or split (longest first) until the count matches the curve, then a
   rebalance pass evens out the lengths without changing the count.
6. **Cube constraint.** Candidates must contain a rising minimum number of seam
   crossings. This prevents the renderer from being a cosmetic cube holding
   unrelated 2D puzzles.
7. **Advanced field.** From level 91, internal path tiles become rotors. Corners are preferred
   because their four-state cycle creates the strongest routing decision; the
   target orientation is derived from the covering, and a deterministic hash
   chooses a different initial orientation. Levels 1–90 contain no rotors; the
   count then rises gradually from one to five.

Ten valid candidate cubes are built per level and scored on turn density, seam
use and colour balance. A deterministic Hamiltonian fallback covers the surface
if every random attempt fails; odd full cubes use a parity-safe joined face
pair rather than an invalid straight concatenation.

Because the generated partition covers every playable cell and each path is a
simple path, it is a guaranteed non-crossing solution certificate. The player
is not required to reproduce that covering and may leave tiles empty while
connecting the same pairs by other routes. Solvability is a property of
construction, not of search — there is no solver at runtime and there is no way
to ship an unsolvable board. `CubeLevelValidator` asserts the certificate
invariants anyway, on every cube, before it reaches the player.

### Determinism

`SeededRandom` is SplitMix64. The seed is derived from `(level, track, salt,
attempt)`, so:

- the same level is the same board on every device and in every build;
- the two tracks never share a board;
- the daily challenge is salted by the date, so everyone gets the same one.

`Hasher` is deliberately unstable per process, so `SeededRandom.hash` is a
hand-rolled FNV-1a — using `Hasher` would silently reshuffle every daily board
on every launch.

## Difficulty curve

A designed stage table, not a linear ramp: the curve flattens where
hybrid-casual funnels lose players (the first ten levels, and again around
level 30) instead of climbing straight through them.

| Free track | Tile grid per face | Active faces | Circuits |
|---|---:|---:|---:|
| 1–4 | 3×3 | 2 | 3 |
| 5–11 | 3×3 | 3 | 4 |
| 12–21 | 3×3 | 4 | 5 |
| 22–31 | 3×3 | 5 | 6 |
| 32–45 | 3×3 | 6 | 7 |
| 46–59 | 4×4 | 4 | 7 |
| 60–77 | 4×4 | 5 | 8 |
| 78–104 | 4×4 | 6 | 9 |
| 105–134 | 5×5 | 5 | 11 |
| 135+ | 5×5 | 6 | 12 |

The Pro track begins on four faces, reaches all six by level 8, and eventually
uses 5×5 tiles with 14 circuits. It also adds connected wall tiles after level
12. The subscription therefore changes how soon the object unfolds and how
dense its field becomes, without introducing a separate save or product.

On top of the table:

- **Boss levels** every 10th: one size step up and one extra colour.
- **Breather levels** every 7th non-boss: two colours fewer, no walls. Failure
  streaks are what end sessions; a deliberate easy board interrupts them.
- **Face unfolding**: the first levels teach one visible corner; later stages
  demand spatial memory across the complete object.
- **Twistiness target**: the candidate scorer raises turn density gradually and
  separately rewards seam use. Early cubes read cleanly; late ones are knotted.

## Scoring

Par is one drag per pair **plus, after level 90, the exact clockwise turns needed
on the generated certificate route**. Thresholds are relative to par rather than absolute, which is
what lets them hold for fields nobody has tuned by hand:

- **3 stars**: solved in par or better, with no hints.
- **2 stars**: within par + max(2, par/2), or any solve that used a hint.
- **1 star**: solved.

Gems are `4 + 3 × stars`, +10 on a boss, cut to a third on a replay so the
campaign cannot be farmed, and doubled for Pro subscribers.

## Retention

- **Endless campaign.** There is always a next level. The map always shows one
  chapter beyond where the player has reached.
- **Chapters** of 30 levels with cycling names and palettes, so progress has
  visible milestones without authoring content.
- **Daily puzzle**, one board per calendar day, identical for everyone,
  generated from the date. It costs no content budget and gives a reason to
  open the app on a day the player has no campaign appetite.
- **Streaks** count consecutive days played and raise the daily bonus up to a
  cap. Streak state is keyed on the local calendar day, not on elapsed hours,
  so a player in any time zone gets exactly one daily per day.
- **Cosmetic collection.** Four categories, 22 items, with ladders that mix
  star unlocks (play), gem unlocks (play or pay) and Pro-only items (pay).
  Nothing cosmetic changes difficulty.

## Accessibility

- Both endpoints in a pair use the same strong colour and identical target
  shape. **Colour-blind assist** also adds a unique four-pip binary marker to
  every endpoint pair, so colour is never the only way to match up to 14 circuits.
- Palettes are chosen by **maximising the minimum CIE76 distance** between
  their colours, verified at build time (worst case across all eight palettes:
  ΔE 30.9, threshold 22). Distinguishable colours are a gameplay requirement
  here, not a styling preference.
- **Reduce motion** stills the animated backdrops, and the system accessibility
  setting is honoured whether or not the in-app one is on.
- The board exposes a summary accessibility label; every control is labelled.
