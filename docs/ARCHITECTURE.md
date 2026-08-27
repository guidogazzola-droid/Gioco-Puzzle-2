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
  PuzzleEngine  ←  LevelGenerator
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

The board is a single `Canvas` pass, not a grid of views. A 13×13 board is 169
cells plus up to 14 trails plus 28 endpoint markers; as views that is a layout
pass per frame under a drag, and as one draw call it is not.

`BoardGeometry` owns the mapping in both directions — point→cell for the
gesture, cell→rect for the drawing. Keeping it in one value type is what stops
hit-testing and drawing from drifting apart, which is the classic way a grid
game ends up feeling "off by half a cell".

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
| `PuzzleKitTests` | `swift test`, anywhere | generation, engine rules, scoring, entitlements, ad pacing, save migration |
| `LineFlowTests` | Xcode / `xcodebuild test` | persistence on disk, board geometry, service wiring, theme resolution |
| `tools/verify.py` | Python, anywhere | the generation algorithm as an executable spec, palettes, localisation, product wiring, project file |

The Python harnesses are not a substitute for the Swift tests; they cover what
a Swift test cannot reach. `tools/generator_reference.py` is a line-for-line
twin of `LevelGenerator.swift` and is how the algorithm itself was validated —
800 levels across both tracks with zero invalid boards — independently of the
port.

## Conventions

- No force-unwraps on anything derived from data (catalogue lookups, palettes,
  cosmetic ids all have fallbacks). A missing skin id renders the default; it
  never leaves the board unpainted.
- Public API in PuzzleKit is documented where the *reason* is not obvious from
  the name. Comments explain why, not what.
- Localisation keys are dotted and namespaced by screen.
  `tools/check_localization.py` fails on a key that is referenced but missing,
  defined but unused, or present in one language and not the other.
