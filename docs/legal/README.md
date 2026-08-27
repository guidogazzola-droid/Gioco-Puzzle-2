# Published legal pages

The source of the three pages hosted at
`https://www.sabettaworks.com/games/lineflow/`. They live in the repository
rather than only on the website for one reason: **the privacy policy is a claim
about what the code does**, and the two have to move together.

| File | Published at |
|---|---|
| `privacy-en.md` | `/games/lineflow/privacy` |
| `privacy-it.md` | `/games/lineflow/privacy-it` |
| `terms-en.md` | `/games/lineflow/terms` |
| `terms-it.md` | `/games/lineflow/terms-it` |
| `support-en.md` | `/games/lineflow/support` |
| `support-it.md` | `/games/lineflow/support-it` |

The same URLs are in `LineFlow/Services/LegalLinks.swift` and have to be entered
in App Store Connect. All three must resolve before submission: a broken privacy
or terms link is a guideline 3.1.2 rejection, and App Store Connect will not
accept a build without a support URL.

## Before publishing

Fill in the placeholders. `[LEGAL ENTITY NAME]` / `[RAGIONE SOCIALE]` and
`[REGISTERED ADDRESS]` / `[SEDE LEGALE]` appear in the privacy and terms pages.
The GDPR requires the data controller to be identifiable, so "Sabetta Works"
alone is not enough if that is not a registered name.

`support@sabettaworks.com` has to be a mailbox somebody reads. App Review has
been known to write to it.

## What makes these pages wrong

Today they are accurate: the app has no networking of its own, no analytics, no
advertising SDK, and stores one local save file. `PrivacyInfo.xcprivacy`
declares the same thing.

Each of the following changes makes the privacy policy false the day it ships,
so the page and the App Store privacy label have to change in the same release:

- **Linking an advertising network.** The largest one. It brings its own
  identifiers, its own tracking domains, and its own privacy manifest that Xcode
  merges into the app's privacy report. `NSPrivacyTracking` becomes true.
- **Adding analytics or crash reporting**, including Apple's own if it collects
  anything beyond what Apple already collects for you.
- **Syncing the save to iCloud.** The "never leaves your device" paragraph stops
  being true.
- **Any server of your own** — accounts, cloud saves, remote level packs,
  anything that makes a network request the app controls.

A useful habit: when a pull request adds a dependency, ask what it sends. If the
answer is anything, this directory is part of that pull request.
