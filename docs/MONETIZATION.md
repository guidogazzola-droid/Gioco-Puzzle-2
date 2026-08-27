# Monetisation

Free to download, three revenue lines: ads, one-off purchases, and a
subscription. The design rule underneath all of it is that **nothing sold makes
a puzzle easier to solve**. Hints exist and are sold, but they cap the level at
two stars, so buying them costs the thing a puzzle player actually wants.

## What is sold

All identifiers live in one Swift enum (`StoreProductID`) so a typo cannot
silently break a purchase. `tools/check_products.py` checks them against
`Configuration/Products.storekit` and against both localisation files.

| Identifier | Kind | Suggested price (IT) | Grants |
|---|---|---|---|
| `com.sabettaworks.LineFlowSW.removeads` | Non-consumable | €3,99 | No ads, forever |
| `com.sabettaworks.LineFlowSW.style.orchid` | Non-consumable | €4,99 | Orchid palette |
| `com.sabettaworks.LineFlowSW.style.neon` | Non-consumable | €4,99 | Comet trail + Starfield backdrop |
| `com.sabettaworks.LineFlowSW.gems.pouch` | Consumable | €1,99 | 500 gems |
| `com.sabettaworks.LineFlowSW.gems.chest` | Consumable | €4,99 | 1 500 gems |
| `com.sabettaworks.LineFlowSW.gems.vault` | Consumable | €9,99 | 4 000 gems |
| `com.sabettaworks.LineFlowSW.pro.monthly` | Auto-renewable | €4,99/month | Everything, 1-week free trial |
| `com.sabettaworks.LineFlowSW.pro.yearly` | Auto-renewable | €39,99/year | Everything, 1-week free trial |

Subscription group `22339558` ("Line Flow SW Pro"), both plans family-shareable.
Prices are a starting point; App Store pricing is per storefront and the app
never hard-codes a price — every price shown comes from StoreKit.

## Who writes the words on the paywall

Two different sources, and they are easy to confuse:

- The **shop screen** reads the app's own `.strings` files, so it follows the
  language of the device.
- The **paywall's plan picker** is Apple's `SubscriptionStoreView`. It renders
  whatever StoreKit hands it, and StoreKit's copy comes from App Store Connect
  (or from `Products.storekit` when testing). The app's `.strings` never reach
  it.

So a product missing a language shows up as a half-translated paywall: the
surrounding screen in English, the plans in Italian. Nothing errors.
`tools/check_products.py` now fails when any product or the subscription group
is missing copy for a language the app ships, which catches the local half of
it; the App Store Connect half is section 2 of the release checklist.

### Testing in another language

`Configuration/Products.storekit` pins the test store's language and country:

```json
"_locale" : "it_IT",
"_storefront" : "ITA",
```

These are testing-only settings and are not read on a real device. `_locale`
picks which localisation StoreKit serves back, **regardless of the device
language** - which is why the simulator can show an English app with Italian
plan names. `_storefront` picks the currency.

Change them in Xcode by opening the file and using the Editor menu, or by
editing the two lines. Setting `_locale` to `en_US` while leaving `_storefront`
as `ITA` gives English copy at euro prices, which is the combination worth
looking at before shipping: it is what an English-speaking player in Italy sees.

## The entitlement rules

`Entitlements` is the single source of truth. Every gate in the game reads from
it, so the rules live in one unit-tested place instead of being re-derived in
each view.

```
showsAds          = !boughtRemoveAds && !isPro
unlocksProTrack   = isPro
hasUnlimitedHints = isPro
gemMultiplier     = isPro ? 2 : 1
canUse(cosmetic)  = ownedOutright(cosmetic) || isPro
```

`isPro` is true for an **active** subscription *and* during a **grace period**,
and false during a **billing retry**. That distinction matters: Apple keeps
serving content during a grace period while it retries the charge, and cutting
someone off mid-grace is both wrong and a refund magnet.

### What happens when a subscription lapses

Cosmetics bought with money, gems or stars are owned outright and survive.
Pro-only cosmetics revert. If the player had a Pro-only skin equipped,
`Entitlements.sanitized` swaps it for the category default, so the board is
never rendered with something the player can no longer change back. This runs
on every entitlement change and on every foreground.

`AppServices.resetProgress` deliberately keeps purchases and settings: deleting
something a player paid for because they tapped "reset progress" would be
indefensible.

## Ad pacing

`AdPolicy` is data, not code paths, so it can be tuned from analytics without
touching the game loop. Defaults:

| Setting | Default | Why |
|---|---|---|
| `newPlayerGraceLevels` | 5 | The first session has to sell the game, not the ad inventory |
| `levelsBetweenInterstitials` | 3 | |
| `minimumSecondsBetween` | 90 | A fast player on easy boards should not be carpet-bombed |
| `showsOnlyAfterSuccess` | true | Interrupting someone who just failed is the fastest way to lose them |

Rewarded video is offered in three places, always as a choice and never as a
wall: a hint when the player is stuck, gems in the shop, and a peek at the Pro
track from the paywall. The reward is granted **only** if the unit ran to the
end — abandoning it forfeits the reward, which is what a real network reports
and what `SimulatedAdService` reproduces.

Pacing counters live in the save file, so they survive a relaunch. Restarting
the app is not a way to skip an ad.

## Wiring a real ad network

The game talks to the `AdService` protocol and never to a network SDK, so the
vendor is a swap of one file. What ships is `SimulatedAdService`, which renders
an in-app placeholder — that keeps the project buildable with no third-party
dependency and lets the pacing rules be felt in the simulator.

To go live with, say, AdMob:

1. Add the SDK (SwiftPM: `googleads-mobile-sdk-ios`).
2. Write `AdMobService: AdService`. Map `showInterstitial()` onto presenting a
   loaded `GADInterstitialAd` and returning when it is dismissed;
   `showRewarded(_:)` onto `GADRewardedAd`, returning `true` only from the
   reward callback.
3. Swap the instance in `AppServices.init`. Nothing else changes.
4. Add `GADApplicationIdentifier` to `Info.plist`, and the network's
   `SKAdNetworkItems` list. Do not invent those identifiers — take them from
   the network's published list.
5. Request App Tracking Transparency **before** initialising the SDK if you
   want personalised ads. `NSUserTrackingUsageDescription` is already in
   `Info.plist`; call `ATTrackingManager.requestTrackingAuthorization` and pass
   the result into `AdService.configure(allowsPersonalisedAds:)`. Ask at a
   moment that makes sense — after a few levels, not on first launch.
6. Update `LineFlow/PrivacyInfo.xcprivacy`: set `NSPrivacyTracking` to true,
   list the network's tracking domains, and declare the data types it collects.
   The SDK ships its own manifest that Xcode merges into the privacy report,
   but yours must be honest about your own use.
7. Update your App Store Connect privacy answers to match.

Do **not** ship personalised ads to users who declined ATT, and do not ship
them at all to accounts flagged as children.

## Numbers worth watching

The levers, roughly in order of impact:

1. **`newPlayerGraceLevels`** — moving this is the fastest way to trade day-1
   retention against ad revenue.
2. **Paywall entry points** — the game raises it from the Pro card, from a
   Pro-only cosmetic, from the hint sheet and from the remove-ads tile. Each
   should be measured separately; they convert very differently.
3. **The free trial** — one week, on both plans. It is the largest single lever
   on subscription conversion, and `tools/check_products.py` fails the build if
   a plan ever loses it.
4. **Gem prices for cosmetics** — 200 to 500 gems against roughly 13 gems per
   first clear puts the first purchasable skin about 15–20 levels out, which is
   past the point where a player has decided whether they like the game.
5. **`levelsBetweenInterstitials`** — the obvious lever, and the one most
   likely to cost more in retention than it earns.
