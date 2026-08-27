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

- [ ] Create all four with the settings above. The daily one is a **recurring**
      leaderboard — that is what makes it a fresh race each day, matching the
      generated board everyone gets.
- [ ] Give each a localised name in English and Italian. The strings the app
      already uses are `leaderboard.*.title` in both `.strings` files.
- [ ] Test on a real device signed into Game Center. The simulator can
      authenticate but is unreliable for score submission.
- [ ] Check the game still plays normally with Game Center **off** (sign out, or
      restrict it in Screen Time). Leaderboards are optional by design and
      nothing in the game loop waits on them.

## 3. Legal (guideline 3.1.2 — the most common subscription rejection)

- [ ] Host a real privacy policy and replace `LegalLinks.privacyPolicy` in
      `LineFlow/Services/LegalLinks.swift`. The placeholder domain is not real.
- [ ] Host a support page and replace `LegalLinks.support`.
- [ ] Enter the same privacy policy URL in App Store Connect.
- [ ] Terms of Use: the repo links Apple's standard EULA, which is acceptable.
      If you write your own, replace `LegalLinks.termsOfUse` **and** paste the
      text into App Store Connect.
- [ ] Verify on-device that the paywall shows, without scrolling: the plan name,
      the length of the period, the price per period, and working links to both
      documents. `SubscriptionStoreView` renders these from StoreKit — check it
      on the smallest supported device.
- [ ] Verify the auto-renewal disclosure text is visible in the shop
      (`shop.legal` in both languages).

## 4. Privacy

- [ ] `LineFlow/PrivacyInfo.xcprivacy` as committed declares no tracking and no
      data collection, which is true of the app **as shipped in this repo**.
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
- [ ] Ship a cosmetic drop monthly. It is the promise the subscription makes,
      and the cheapest content to produce — the palette generator builds a new
      verified set in seconds.
