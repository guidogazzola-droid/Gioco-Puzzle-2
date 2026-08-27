# App Store release checklist

Everything between "it runs in the simulator" and "it is on sale". Ordered so
each step unblocks the next.

## 1. Identity (do this first — everything else keys off it)

- [ ] Enrol in the Apple Developer Program (€99/year; as an individual or a
      company — a company enrolment needs a D-U-N-S number and takes longer).
- [ ] Pick a real bundle identifier and replace `com.sabettalineflow.app` in:
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

## 2. Products in App Store Connect

Create every product with **exactly** the identifiers in `ProductCatalog.swift`.
A mismatch shows up as a product that silently never loads.

- [ ] `…​.removeads` — non-consumable
- [ ] `…​.style.orchid`, `…​.style.neon` — non-consumable
- [ ] `…​.gems.pouch` / `.chest` / `.vault` — consumable
- [ ] Subscription group "Line Flow SW Pro" containing `…​.pro.monthly` and
      `…​.pro.yearly`, both with a **1-week free trial** introductory offer
- [ ] Replace `ProductCatalog.subscriptionGroupID` with the real group id that
      App Store Connect assigns. The value in the repo matches the local
      StoreKit file, not your account.
- [ ] Localise every product's display name and description for each language
      you ship (English and Italian are already written in the `.strings` files
      — reuse that copy).
- [ ] Upload a **subscription review screenshot** for each plan, and fill in the
      review notes. Missing these is a common rejection.
- [ ] Fill in the subscription **App Store promotion** artwork if you want the
      plans to appear outside the app.

## 2b. Game Center leaderboards

App Store Connect → your app → **Game Center** → Leaderboards. The identifiers
must match `PuzzleKit/Sources/PuzzleKit/Social/Leaderboards.swift` exactly: a
wrong id fails **silently** at submission — no crash, no warning, the score
just never appears.

| Leaderboard ID | Format | Sort | Reset |
|---|---|---|---|
| `com.sabettalineflow.app.leaderboard.stars` | Integer | High to low | Never |
| `com.sabettalineflow.app.leaderboard.free` | Integer | High to low | Never |
| `com.sabettalineflow.app.leaderboard.pro` | Integer | High to low | Never |
| `com.sabettalineflow.app.leaderboard.daily` | Elapsed Time (seconds) | **Low to high** | **Every day** |

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
      Show the board first — a puzzle game sells on the board.
- [ ] App preview video (optional, converts well for puzzle games).
- [ ] Description, keywords, promotional text — in English and Italian.
- [ ] Set the primary category to Games → Puzzle.

## 9. After launch

- [ ] Watch day-1 and day-7 retention against `newPlayerGraceLevels` before
      touching any other ad setting.
- [ ] Watch trial-to-paid conversion per paywall entry point.
- [ ] Watch the funnel from "first paywall view" to "purchase", split by which
      screen raised it.
- [ ] Ship a cosmetic drop monthly. It is the promise the subscription makes,
      and the cheapest content to produce — the palette generator builds a new
      verified set in seconds.
