# Architecture

## The split

```
┌──────────────────────────────────────────────────────┐
│ LineFlow (app target)                               │
│   SwiftUI views · StoreKit · ads · persistence        │
├──────────────────────────────────────────────────────┤
│ PuzzleKit (Swift package)                            │
│   generation · gameplay · progression · economy rules │
│   Foundation only — no SwiftUI, no UIKit, no StoreKit │
└──────────────────────────────────────────────────────┘
```

Everything that can be decided without a screen lives in PuzzleKit. That is not
tidiness for its own sake: it is why the generator, the win rules, the star
thresholds, the entitlement table and the ad pacing all have tests that run
with `swift test` on any platform, with no simulator and no Xcode.

The rule for what goes where: **if it has an answer that does not depend on
pixels, it belongs in PuzzleKit.**

## Data flow

```
     ProfileStore            StoreManager
   (save file JSON)       (StoreKit 2 facts)
          │                       │
          └───────┬───────────────┘
                  ▼
             AppServices
    entitlements = merge(both)
    theme        = resolve(sanitised cosmetics)
                  │
      ┌───────────┼───────────┐
      ▼           ▼           ▼
  GameViewModel  Views    AdService
      │
      ▼
 CubePuzzleEngine  ←  CubeLevelGenerator
```

`AppServices` is the only place the save file, the App Store and the ad network
meet. Views read state from it and call intents on it; none of them talk to
StoreKit or the ad service directly. That is what keeps the entitlement rules in
one testable place rather than spread across a dozen `if isPro` checks.

`Entitlements` is assembled fresh on each read from two sources: what StoreKit
knows (purchases, subscription state) and what the save file knows (stars, gems
already spent). Neither source is authoritative alone.

## Observation

The app uses `@Observable` (not `ObservableObject`) throughout. `AppServices`
holds `@Observable` services, and reading `services.profile.gems` in a view body
registers a dependency through both hops, so a gem award redraws exactly the
views that show gems.

Everything that touches UI state is `@MainActor`. PuzzleKit is `Sendable`
value types with no shared mutable state, so it is free of actor concerns
entirely.

## Rendering

`CubeBoardView` embeds a non-AR RealityKit scene in SwiftUI. The camera, lights,
cube core, surface tiles and collision shapes persist for the life of a level;
only trail and rotor entities are refreshed while the engine changes. This
keeps finger tracking responsive without rebuilding up to 150 collision tiles
on every drag event.

Every tile is named from `(face, x, y)`, so RealityKit hit-testing returns the
same `CubeCell` used by generation and gameplay. `CubeTopology` owns seam
folding for all consumers. Trails crossing an edge are rendered as two surface
segments meeting at a bevel point rather than as a chord through the cube.

An empty-surface pan rotates `cubeRoot`; a pan beginning on N or a loose trail
end routes current. Lifting to expose a hidden face and resuming the loose end
does not add another scored move.

`GameTheme` is the one place cosmetic ids become drawing values. Adding a skin
means adding a catalogue entry and a case in an enum; it never means touching
the renderer.

## Persistence

One JSON document in Application Support, written atomically, with saves
coalesced so a burst of small changes is one write.

Decoding is field-by-field with defaults rather than the synthesised
initialiser. A save written by an older build must never fail to load — wiping
progress on update is how a puzzle game earns one-star reviews. A file that
cannot be decoded at all is **moved aside**, not overwritten: it is the only
copy of that player's progress.

## Testing

| Suite | Runs with | Covers |
|---|---|---|
| `PuzzleKitTests` | `swift test`, anywhere | cube topology, generation, engine rules, scoring, entitlements, ad pacing, save migration |
| `LineFlowTests` | Xcode / `xcodebuild test` | persistence on disk, cubical service wiring, theme resolution, legacy geometry |
| `tools/verify.py` | Python, anywhere | the generation algorithm as an executable spec, palettes, localisation, product wiring, project file |

The Python harness remains an independent executable specification for the
legacy generator and validates shared palettes, localisation, products and the
project file. Swift tests additionally sweep the cubical generator and prove
all face-edge transforms reversible at every supported side length.

## Conventions

- No force-unwraps on anything derived from data (catalogue lookups, palettes,
  cosmetic ids all have fallbacks). A missing skin id renders the default; it
  never leaves the board unpainted.
- Public API in PuzzleKit is documented where the *reason* is not obvious from
  the name. Comments explain why, not what.
- Localisation keys are dotted and namespaced by screen.
  `tools/check_localization.py` fails on a key that is referenced but missing,
  defined but unused, or present in one language and not the other.
