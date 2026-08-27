import Foundation

/// Links Apple requires an app selling subscriptions to expose.
///
/// Guideline 3.1.2 requires the paywall to state the title, length and price
/// of the subscription and to link functional Terms of Use and a Privacy
/// Policy. A submission with either link broken is rejected, so these are
/// checked off in `docs/APP_STORE_CHECKLIST.md` before every release.
enum LegalLinks {

    /// Apple's standard EULA is acceptable as the Terms of Use unless you ship
    /// your own. If you write your own, replace this and paste the same text
    /// into App Store Connect.
    static let termsOfUse = URL(
        string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
    )!

    /// REPLACE BEFORE SUBMISSION with your hosted privacy policy. It must also
    /// be entered in App Store Connect, and it must describe the ad SDK's data
    /// collection if you ship one.
    static let privacyPolicy = URL(string: "https://lineflow.example.com/privacy")!

    static let support = URL(string: "https://lineflow.example.com/support")!

    /// Deep link to the system subscription management screen.
    static let manageSubscriptions = URL(
        string: "https://apps.apple.com/account/subscriptions"
    )!
}
