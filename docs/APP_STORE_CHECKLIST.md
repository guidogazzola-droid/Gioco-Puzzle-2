# App Store release checklist

Everything between "it runs in the simulator" and "it is on sale". Ordered so
each step unblocks the next.

## 1. Identity (do this first — everything else keys off it)

- [ ] Enrol in the Apple Developer Program (€99/year; as an individual or a
      company — a company enrolment needs a D-U-N-S number and takes longer).
- [ ] Pick a real bundle identifier and replace `com.sabettaworks.LineFlowSW` in:
      `LineFlow.xcodeproj` (both `PRODUCT_BUNDLE_IDENTIFIER` settings), the
      test target (`…​.tests`), and every product id in
      `PuzzleKit/Sources/PuzzleKit/Economy/ProductCatalog.swift` and
      `Configuration/Products.storekit`.
      Then run `python3 tools/check_products.py` — it will tell you if you
      missed one.
- [ ] Set `DEVELOPMENT_TEAM` in the project (Signing & Capabilities → Team).
- [ ] Register the App ID with **In-App Purchase** *and* **Game Center**
      enabled. Game Center has to be on the App ID before you build: the app
      ships `LineFlow/LineFlow.entitlements` declaring it, and a provisioning
      profile that does not match the entitlement fails signing with a message
      that does not mention Game Center at all.
- [ ] Check the name "Line Flow SW" is free on the App Store, and reserve it.

## 2a. In-app purchases

App Store Connect → your app → **Monetization → In-App Purchases** (older
layouts put this under *Features*).

**Only six of the eight products go here.** Auto-renewable subscriptions are
*not* in-app purchases in App Store Connect's model and live in their own
section — see 2b. This trips everyone up once.

Create each with **exactly** the identifier in `ProductCatalog.swift`. A
mismatch shows up as a product that silently never loads: no crash, no error,
the shop row just shows a dash.

- [ ] `…​.removeads` — Non-Consumable
- [ ] `…​.style.orchid` — Non-Consumable
- [ ] `…​.style.neon` — Non-Consumable
- [ ] `…​.gems.pouch` — Consumable
- [ ] `…​.gems.chest` — Consumable
- [ ] `…​.gems.vault` — Consumable
- [ ] Localise each one's display name and description for every language you
      ship. English and Italian are already written: reuse the `product.*.name`
      and `product.*.description` values from the `.strings` files so the store
      listing and the app never drift apart.
- [ ] Upload a review screenshot for each and fill in the review notes.

## 2b. Subscriptions

A different section: **Monetization → Subscriptions**. You cannot create a
subscription on its own — the **group comes first**, because the group is what
lets a player move between plans without paying twice.

- [ ] Create the subscription group. Give it a localised **display name**
      ("Line Flow SW Pro") — this is what the player sees in their Apple Account
      subscription settings, not the plan name.
- [ ] Inside the group, create `…​.pro.monthly` — duration **1 month**.
- [ ] Inside the group, create `…​.pro.yearly` — duration **1 year**.
- [ ] Give both the **same level** in the group. Level is the service tier, and
      these two are the same tier bought at different cadences. Same level makes
      monthly → yearly a crossgrade that takes effect at the next renewal;
      different levels would make it an upgrade that refunds and rebills
      immediately, which is not what either of you wants.
- [ ] Add a **1-week free trial** introductory offer to each.
- [ ] Localise the display name and description of each plan, in **every**
      language the app ships. This is the copy Apple's own paywall control
      renders - the app's `.strings` files do not reach it - so a plan missing
      a language shows a paywall in English around plan names in Italian. It
      fails silently, with no error anywhere.
- [ ] Upload a **subscription review screenshot** for each plan and fill in the
      review notes. Missing these is a common rejection.
- [x] The group id is set: `22339558`, in `ProductCatalog.subscriptionGroupID`
      and in `Products.storekit`. It is account-specific — if the group is ever
      recreated, both have to change together: a wrong id returns no
      subscription status at all, so every subscriber would read as
      unsubscribed.
- [ ] Optional: fill in the **App Store promotion** artwork if you want the
      plans to be promotable outside the app.

## 2c. Game Center leaderboards

App Store Connect → your app → **Game Center** → Leaderboards. The identifiers
must match `PuzzleKit/Sources/PuzzleKit/Social/Leaderboards.swift` exactly: a
wrong id fails **silently** at submission — no crash, no warning, the score
just never appears.

| Leaderboard ID | Format | Sort | Reset |
|---|---|---|---|
| `com.sabettaworks.LineFlowSW.leaderboard.stars` | Integer | High to low | Never |
| `com.sabettaworks.LineFlowSW.leaderboard.free` | Integer | High to low | Never |
| `com.sabettaworks.LineFlowSW.leaderboard.pro` | Integer | High to low | Never |
| `com.sabettaworks.LineFlowSW.leaderboard.daily` | Elapsed Time (seconds) | **Low to high** | **Every day** |

Every field the **Add Leaderboard** form asks for, per board:

| Field | stars | free | pro | daily |
|---|---|---|---|---|
| Type | Classic | Classic | Classic | **Recurring** |
| Reference name | Total stars | Furthest free level | Furthest Pro level | Daily puzzle time |
| Score format | Integer | Integer | Integer | **Elapsed Time – to the Second** |
| Submission type | Best Score | Best Score | Best Score | Best Score |
| Sort order | High to Low | High to Low | High to Low | **Low to High** |
| Score range | leave empty | leave empty | leave empty | leave empty |

Three ways to get this silently wrong:

- **The daily sorts Low to High.** A time is better when it is smaller. Set it
  high-to-low and the slowest player tops the board, with no error anywhere.
- **The daily must be "to the Second", not to a hundredth.** The app submits
  `outcome.seconds`, a whole number of seconds. Pick a hundredths format and
  every time renders a hundred times too small.
- **A leaderboard cannot be removed once it has shipped in any version.** The
  identifiers have to be right the first time.

- [ ] Create all four with the settings above.
- [ ] For the recurring daily board: duration **1 day**, repeating **every 1
      day**, starting at **00:00 Italian time** on a date in the future.

      The start time is a real choice, not a formality. The puzzle is keyed to
      the *calendar date* through `Calendar.current`, so everyone playing on the
      28th gets the identical board wherever they are — that part is sound. But
      the leaderboard period turns over at **one fixed instant** for the whole
      world, so wherever local midnight and that instant disagree, a period can
      briefly hold times from two different boards.

      That mismatch cannot be removed, only aimed. Point it at the audience: at
      00:00 Rome, Italian players get the board and the leaderboard turning over
      together, and everyone else drifts. UTC midnight would be the right answer
      for a UK-first launch and is the wrong one here.

      The alternative is to seed the daily from UTC instead of the local
      calendar, which aligns every player exactly at the cost of the board
      changing mid-evening in the Americas and mid-morning in Asia. Worth doing
      only if the daily board turns out to matter competitively — and it is a
      code change, not a setting.
- [ ] Give each a localised name in English and Italian. Use exactly the names
      the app already shows, or the same board reads as two different things
      depending on where a player is looking:

      | Leaderboard | English | Italiano |
      |---|---|---|
      | `…leaderboard.stars` | Stars collected | Stelle raccolte |
      | `…leaderboard.free` | Furthest level | Livello più lontano |
      | `…leaderboard.pro` | Furthest Pro level | Livello Pro più lontano |
      | `…leaderboard.daily` | Daily puzzle | Puzzle del giorno |

      The score-format suffix is "star / stars" and "stelle" for the first, and
      nothing for the level boards - a bare number reads better than "level 42
      levels". The daily board is a time and formats itself.
- [ ] **Achievements: none.** Leave the section empty. Nothing in the code
      reports one, and an achievement cannot be removed once it has shipped in
      any version — so adding a speculative one now is a permanent decision
      made for no reason. The same goes for **Challenges**, which additionally
      need achievements or leaderboards already live to build on.
- [ ] Test on a real device signed into Game Center. The simulator can
      authenticate but is unreliable for score submission.
- [ ] Check the game still plays normally with Game Center **off** (sign out, or
      restrict it in Screen Time). Leaderboards are optional by design and
      nothing in the game loop waits on them.

## 2d. What to leave empty

Two sections of App Store Connect look like they are waiting for something and
are not.

**App Store Server Notifications** (production and sandbox URLs) — leave both
unset. These are webhooks Apple sends to *your server* when a subscription
renews, lapses, is refunded or hits a billing problem. This game has no server:
`StoreManager` decides entitlement on the device from Apple-signed transactions
(`Transaction.updates`, `Transaction.currentEntitlements`,
`Product.SubscriptionInfo.status(for:)`), and re-derives it on every foreground.
Nothing is waiting to be told.

The one thing you give up is knowing about a cancellation or a refund *while
the app is closed*. The app finds out the next time it opens, which for a game
is soon enough — but it does mean there is no way to react to churn as it
happens. Worth revisiting only if you ever add a backend.

**App-specific shared secret** — do not generate one. It exists for the legacy
`verifyReceipt` endpoint, which is server-side receipt validation. StoreKit 2
verifies transactions on-device with JWS signatures; the app never sees a
receipt and has nothing to send anywhere. An unused credential is a small
liability, not a spare part.

Neither field blocks submission.

## 3. Legal (guideline 3.1.2 — the most common subscription rejection)

- [x] The three pages are written, in both languages, in `docs/legal/`.
      `LegalLinks.swift` points at them and serves the Italian page to a player
      whose app is in Italian. `check_project.py` fails the build if a
      placeholder domain ever comes back.
- [x] All six pages are published under `https://sabettaworks.com/games/lineflow/`
      and every one answers 200 — checked with a request, not assumed. The `www`
      host answers 301 to the bare one, which is why `LegalLinks.swift` uses the
      bare form: a redirect is a round trip on every tap and a dependency on a
      DNS record the app cannot be fixed without a release.
- [ ] **Re-publish `privacy-en.md` and `privacy-it.md`.** The live pages are the
      version from before the house advertisements: they do not say the
      advertisements are ours, or that tapping one opens a website under that
      site's own policy. The files in `docs/legal/` do.
- [ ] Check whether **SabettaWorks** is a registered name. The pages name it as
      the data controller with an email and no address; if it is only a trading
      style, the GDPR's requirement that the controller be identifiable is not
      comfortably met by a name and an inbox.
- [ ] Make `hello@sabettaworks.com` a mailbox somebody reads. App Review
      writes to it.
- [ ] Enter the privacy policy URL and the support URL in App Store Connect.
      They are separate fields from anything in the app.
- [ ] Terms of Use: the page incorporates Apple's standard EULA by reference and
      adds the game-specific terms. That is acceptable as-is. If you ever
      replace the EULA rather than reference it, the full text also has to go
      into the EULA field in App Store Connect.
- [ ] Verify on-device that the paywall shows, without scrolling: the plan name,
      the length of the period, the price per period, and working links to both
      documents. `SubscriptionStoreView` renders these from StoreKit — check it
      on the smallest supported device.
- [ ] Verify the auto-renewal disclosure text is visible in the shop
      (`shop.legal` in both languages).

## 4. Privacy

- [ ] `LineFlow/PrivacyInfo.xcprivacy` as committed declares no tracking and no
      data collection, which is true of the app **as shipped in this repo**:
      no networking of its own, no analytics, no ad SDK, one local save file.
      `docs/legal/README.md` lists the four changes that would make the privacy
      policy false the day they ship.
- [ ] If you link an ad or analytics SDK, update it: set `NSPrivacyTracking` to
      true, list the tracking domains, declare the collected data types. See
      `docs/MONETIZATION.md`.
- [ ] Complete the App Privacy questionnaire in App Store Connect to match.
- [ ] If you serve personalised ads, request ATT before initialising the SDK,
      and only after the player has seen some value — not on first launch.

## 5. Ratings and audience

- [ ] Age rating questionnaire. With ads and IAP, expect 4+ with "Infrequent /
      Mild" nothing — the game itself has no objectionable content.
- [ ] If you ever target the Kids Category, you must remove third-party ads and
      behavioural tracking entirely. Do not do this halfway.

## 6. Build

- [ ] Bump `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`.
- [ ] Replace the generated app icon with final art if you have a designer.
      The committed icon is real, opaque and 1024×1024, so it will pass
      validation as-is — regenerate with `python3 tools/make_app_icon.py`.
- [ ] Archive with the Release configuration, validate, upload.
- [ ] Read the bundle identifier in the Organizer before uploading: it must be
      `com.sabettaworks.LineFlowSW`, matching the App Store Connect record.
      Xcode reports a mismatch as `IDEDistribution.DistributionAppRecordProviderError
      error 0`, which is an unhelpful way of saying "no app on this account has
      that identifier". Archiving an out-of-date checkout is the usual cause -
      the identifier changed once already, from `com.prismflow.game`.
- [ ] Confirm `ITSAppUsesNonExemptEncryption` is `false` in `Info.plist` so the
      export-compliance questionnaire is skipped on every upload.

## 7. Testing before submission

- [ ] `python3 tools/verify.py` — all five checks green.
- [ ] `cd PuzzleKit && swift test` — the whole game-logic suite.
- [ ] `xcodebuild test` for the app target.
- [ ] In the simulator with `Configuration/Products.storekit`: buy each product,
      subscribe, **cancel and let it expire** (use the scheme's transaction
      time rate), and confirm the Pro-only skins revert while the ones you paid
      for stay.
- [ ] Test **Ask to Buy** (pending transactions) via the StoreKit configuration.
- [ ] Test **refund/revocation** and confirm entitlements drop.
- [ ] Test **restore purchases** on a clean install.
- [ ] Test with **no network**: products fail to load, and the shop shows "—"
      rather than a wrong price or a crash.
- [ ] TestFlight with real sandbox accounts — the local StoreKit file does not
      exercise Apple's servers.
- [ ] VoiceOver pass over the board, the map and the paywall.
- [ ] Check the largest board (Pro level 200, 13×13, 14 colours) on the smallest
      supported screen.

## 8. Store listing

- [ ] Screenshots for every required device size, in every language you ship.
      See section 8b — these are a different thing from the review screenshots
      in sections 2a and 2b, and people mix them up.
- [ ] App preview video (optional, converts well for puzzle games).
- [ ] Description, keywords, promotional text — in English and Italian.
- [ ] Set the primary category to Games → Puzzle.

## 8b. The two kinds of screenshot

They are not interchangeable and App Store Connect asks for them in different
places.

**Review screenshots** (sections 2a and 2b). One per product. Nobody but App
Review ever sees them; their only job is to show the reviewer *where in the app
the purchase appears*, so they can find it. Any resolution, no marketing
polish. One image of the paywall serves both subscriptions; one of the shop
serves the gem packs and the style packs.

**Listing screenshots** (this section). What customers see on the product page.
Specific pixel sizes, per device class, per language. These sell the app.

### Capturing them

The fastest route for review screenshots is the simulator: run the app, get to
the screen, `⌘S` saves a correctly-sized PNG to the Desktop. The simulator
device you pick determines the pixel size, so run the largest iPhone for the
listing shots.

The target ships iPhone only (`TARGETED_DEVICE_FAMILY = "1"`), so iPhone is the
only class the listing needs — no iPad screenshots, and none of the iPad layout
work that showing them honestly would require. Check the required sizes in App
Store Connect itself rather than trusting a list — Apple changes them. At the
time of writing the 6.9" iPhone size covers every iPhone, with Apple scaling
down for the smaller ones.

The app is portrait-only, so the screenshots are portrait.

### What to show, in order

The first two are what appear in search results, so they carry the whole
listing:

1. **A board mid-solve.** A puzzle game sells on the puzzle. Pick a board with
   six or seven colours - busy enough to look interesting, clear enough to read
   at thumbnail size.
2. **A Pro board.** Bigger grid, walls, more colours: this is what the
   subscription buys, and it reads instantly.
3. **Level complete, three stars.** Shows the scoring loop.
4. **The style shop.** Shows there is something to collect.
5. **Leaderboards.** Shows there are other people.

Skip the settings and the onboarding: nobody installs an app because of them.

## 9. After launch

- [ ] Watch day-1 and day-7 retention against `newPlayerGraceLevels` before
      touching any other ad setting.
- [ ] Watch trial-to-paid conversion per paywall entry point.
- [ ] Watch the funnel from "first paywall view" to "purchase", split by which
      screen raised it.
- [ ] Ship cosmetic drops when there is something worth shipping. They are the
      cheapest content the game has — the palette generator builds a new
      verified set in seconds — but nothing promises them on a schedule any
      more, and a promise on the paywall is what a drop would have to keep.
