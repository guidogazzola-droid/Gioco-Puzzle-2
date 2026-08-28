# Game design

## The mechanic

A field is a grid of directional magnetic circuits. Each circuit has an **N
source**, an **S destination**, and zero or more two-port rotors embedded in its
possible route. Drag from N to S to energise a circuit; tap a rotor to turn it
clockwise. A closed port physically rejects the trail. The field is stable when
**every N reaches its matching S, every rotor is aligned, and every playable
cell is energised**.

Requiring full coverage is what makes the puzzle interesting. Without it almost
every board collapses into straight lines and the difficulty curve has nothing
to climb. With it, the player has to reason about the whole board rather than
one pair at a time.

Interaction rules, all implemented in `PuzzleEngine` and unit-tested:

| Action | Result |
|---|---|
| Grab an N pole | Restarts that circuit from its source |
| Grab an S pole | Rejected — current cannot run backwards |
| Tap a rotor | Turns its two open ports clockwise and spends one action |
| Enter a closed rotor port | Rejected with no board mutation |
| Enter another circuit's rotor | Rejected — rotors are circuit-specific |
| Grab a cell mid-trail | Rewinds the colour to that cell and continues |
| Drag back one cell | Rewinds one step |
| Drag onto another colour's trail | Cuts that colour at the crossing point |
| Drag onto another colour's endpoint | Rejected — endpoints are never passable |
| Drag onto a wall | Rejected |
| Reach the far endpoint | The colour locks |

A drag that moves faster than one cell per frame is filled in by
`BoardGeometry.route`, which walks the longer axis first. Without it, a quick
flick leaves gaps in the trail and the game feels broken on the exact swipe
players use most.

## Generation

Levels are generated, never authored. `LevelGenerator` runs four steps:

1. **Walls.** On the Pro track only, wall cells are carved one at a time, each
   checked to keep the remaining board orthogonally connected. An island of
   free cells would be unsolvable.
2. **Partition.** Every free cell is covered by vertex-disjoint simple paths.
   Paths grow from *both* ends with a Warnsdorff-style bias — step onto the
   neighbour with the fewest onward options — which is what stops the board
   fragmenting into stranded single cells. A length cap of 1.5x the average
   stops any one colour swallowing the board.
3. **Repair.** Any length-1 path is grafted onto a neighbour. Grafting onto an
   endpoint merges two paths; grafting mid-path splits the host. Both keep the
   covering valid, so a singleton is always repairable.
4. **Circuit count.** Paths are merged (shortest pair first, which keeps lengths
   even) or split (longest first) until the count matches the curve, then a
   rebalance pass evens out the lengths without changing the count.
5. **Magnetic field.** Internal path cells become rotors. Corners are preferred
   because their four-state cycle creates the strongest routing decision; the
   target orientation is derived from the covering, and a deterministic hash
   chooses a different initial orientation. Density rises from one rotor on the
   first field to five in advanced labs.

Twelve candidate boards are built per level and scored on how close their
turn density is to a target, how many two-cell colours they contain, and
whether any colour has swallowed the board. The best one ships.

Because the partition covers every playable cell and each path is a simple
path, the partition *is* a solution. Solvability is a property of construction,
not of search — there is no solver at runtime and there is no way to ship an
unsolvable board. `LevelValidator` asserts the invariants anyway, on every
board, before it reaches the player.

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

| Free track | Board | Colours |
|---|---|---|
| 1–6 | 5×5 | 3 |
| 7–14 | 5×5 | 4 |
| 15–24 | 6×6 | 4 |
| 25–36 | 6×6 | 5 |
| 37–50 | 7×7 | 5 |
| 51–66 | 7×7 | 6 |
| 67–84 | 8×8 | 6 |
| 85–104 | 8×8 | 7 |
| 105–129 | 9×9 | 7 |
| 130+ | 9×9 | 8 |

The Pro track starts at 7×7 with 5 colours and reaches 12×12 with 13, and adds
wall cells from level 15 (ramping to 10% of the board). That mechanical gap is
what the subscription actually sells — not a bigger number, a different puzzle.

On top of the table:

- **Boss levels** every 10th: one size step up and one extra colour.
- **Breather levels** every 7th non-boss: two colours fewer, no walls. Failure
  streaks are what end sessions; a deliberate easy board interrupts them.
- **Silhouette cycle**: boards go square, short, square, narrow, wide, square on
  a six-level cycle, so late levels keep changing shape after the size curve
  has plateaued.
- **Twistiness target**: the candidate scorer aims at 0.18 turns per cell early
  and 0.52 late on the free track, 0.34 to 0.62 on Pro. Early boards read
  cleanly; late boards are knotted.

## Scoring

Par is one drag per circuit **plus the exact clockwise turns needed to align
every rotor**. Thresholds are relative to par rather than absolute, which is
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

- Every source and destination is permanently labelled **N** or **S**.
  **Colour-blind assist** also puts a distinct letter on every circuit, so
  colour is never the only way to match it. This matters more here than in
  most games: a board with 14 colours is unplayable if two of them read alike.
- Palettes are chosen by **maximising the minimum CIE76 distance** between
  their colours, verified at build time (worst case across all eight palettes:
  ΔE 30.9, threshold 22). Distinguishable colours are a gameplay requirement
  here, not a styling preference.
- **Reduce motion** stills the animated backdrops, and the system accessibility
  setting is honoured whether or not the in-app one is on.
- The board exposes a summary accessibility label; every control is labelled.
