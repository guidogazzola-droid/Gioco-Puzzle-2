import Foundation

/// The pages Apple requires an app selling subscriptions to expose.
///
/// Guideline 3.1.2 requires the paywall to state the title, length and price of
/// the subscription and to link functional Terms of Use and a Privacy Policy. A
/// submission with either link broken is rejected, and App Store Connect will
/// not take a build without a support URL, so all three are checked off in
/// `docs/APP_STORE_CHECKLIST.md` before every release.
///
/// The published text lives in `docs/legal/` in this repository rather than
/// only on the website, because the privacy policy is a claim about what this
/// code does and the two have to move together.
enum LegalLinks {

    // No www: the www host answers, but with a 301 to this one. A redirect is
    // a round trip on every tap and a dependency on a DNS record staying
    // configured, and a broken policy link cannot be fixed without a release.
    private static let base = "https://sabettaworks.com/games/fieldweave"

    /// Italian players get the Italian pages. The app's language, not the
    /// device's region: someone reading the game in Italian should not be
    /// handed an English privacy policy, wherever they happen to be. Anything
    /// other than Italian falls back to English, which is the development
    /// region and the page every other language gets.
    private static var suffix: String {
        Bundle.main.preferredLocalizations.first == "it" ? "-it" : ""
    }

    private static func page(_ name: String) -> URL {
        // Force-unwrapped deliberately: every component is a literal in this
        // file, so a nil here would mean the string above was edited into
        // something that is not a URL - which should fail loudly, at launch,
        // rather than silently render a paywall with no policy link.
        URL(string: "\(base)/\(name)\(suffix)")!
    }

    /// Apple's standard EULA is incorporated by reference on this page, with
    /// the game-specific terms - gems, the subscription, refunds - alongside
    /// it. If you ever replace it, the same text has to go into the EULA field
    /// in App Store Connect.
    static var termsOfUse: URL { page("terms") }

    static var privacyPolicy: URL { page("privacy") }

    static var support: URL { page("support") }

    /// Deep link to the system subscription management screen.
    static let manageSubscriptions = URL(
        string: "https://apps.apple.com/account/subscriptions"
    )!
}
