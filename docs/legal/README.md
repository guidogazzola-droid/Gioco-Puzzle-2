# Published legal pages

The source of the three pages hosted at
`https://sabettaworks.com/games/fieldweave/`. They live in the repository
rather than only on the website for one reason: **the privacy policy is a claim
about what the code does**, and the two have to move together.

| File | Published at |
|---|---|
| `privacy-en.md` | `/games/fieldweave/privacy` |
| `privacy-it.md` | `/games/fieldweave/privacy-it` |
| `terms-en.md` | `/games/fieldweave/terms` |
| `terms-it.md` | `/games/fieldweave/terms-it` |
| `support-en.md` | `/games/fieldweave/support` |
| `support-it.md` | `/games/fieldweave/support-it` |

The same URLs are in `LineFlow/Services/LegalLinks.swift` and have to be entered
in App Store Connect. All three must resolve before submission: a broken privacy
or terms link is a guideline 3.1.2 rejection, and App Store Connect will not
accept a build without a support URL.

## Published, and kept in step

All six pages are live and these files match them. That is the arrangement
worth protecting: when the code changes what the app does, the page changes in
the same commit, and the published copy is updated from here rather than
rewritten from memory.

The controller is named as **SabettaWorks**, contactable at
**hello@sabettaworks.com**, with no postal address. If SabettaWorks is not a
registered trading name, the GDPR's requirement that the data controller be
identifiable is not comfortably met by a name and an inbox — worth checking
once, not something to guess at.

`hello@sabettaworks.com` has to stay a mailbox somebody reads. App Review has
been known to write to it.

### Host

The canonical host is **`sabettaworks.com`**, without `www`. Measured, not
assumed: every page answers 200 there, and the `www` host answers 301 to it.
`LegalLinks.swift` uses the canonical form so a tap costs no redirect and the
app does not depend on a DNS record it cannot be released without.

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
