import SwiftUI

/// The advertisements the game shows, all of them ours.
///
/// Line Flow SW carries no third-party ad network, and that is a decision
/// rather than a gap. A network would bring an ATT prompt, a GDPR consent
/// flow required across the EU even for non-personalised ads, tracking domains
/// in the privacy manifest, and an App Store privacy label that stops saying
/// "Data Not Collected" - all to earn, at this game's likely volumes, less
/// than the work costs. Against that, the slot is worth more as inventory we
/// own: one creative sends players to VidiVadi Planner, the other sells the
/// subscription that removes the slot entirely.
///
/// Creatives are drawn from bundled assets and localised strings. Nothing is
/// fetched, so the claim in the privacy policy - that the app makes no network
/// request of its own - stays true. The cost is that changing an advertisement
/// needs an app update, which at this release cadence is not a cost at all.
struct HouseAd: Identifiable, Equatable {

    enum Destination: Equatable {
        /// Opened in a Safari sheet over the game rather than by handing the
        /// player to Safari. A tap on an advertisement should not end the
        /// session: they read, they dismiss, they are back on the board.
        case web(URL)
        /// For when VidiVadi Planner reaches the App Store. Kept here so that
        /// switching is a change of data, not of code.
        case appStore(id: String)
        /// Opens the paywall. The most valuable thing this slot can sell is
        /// the thing that takes the slot away.
        case paywall
    }

    let id: String
    /// A video creative, bundled with the app. Named without its extension;
    /// the file is `<name>.mp4` in the app's resources.
    let video: String?
    /// SF Symbol, drawn when there is no video. Also the fallback if the video
    /// is ever missing from the bundle, so the slot degrades to a card rather
    /// than to black.
    let icon: String
    let tint: Color
    let titleKey: String
    let bodyKey: String
    let ctaKey: String
    let destination: Destination
}

enum HouseAdCatalogue {

    static let vidivadi = HouseAd(
        id: "vidivadi",
        video: "vidivadi-spot",
        icon: "airplane.departure",
        tint: Color(hex: "#4FC3F7"),
        titleKey: "ad.vidivadi.title",
        bodyKey: "ad.vidivadi.body",
        ctaKey: "ad.vidivadi.cta",
        destination: .web(URL(string: "https://www.vidivadi.com")!)
    )

    static let pro = HouseAd(
        id: "pro",
        video: nil,
        icon: "crown.fill",
        tint: Color(hex: "#B478FF"),
        titleKey: "ad.pro.title",
        bodyKey: "ad.pro.body",
        ctaKey: "ad.pro.cta",
        destination: .paywall
    )

    static let all: [HouseAd] = [vidivadi, pro]

    /// The next creative to show.
    ///
    /// Round-robin rather than random: with a catalogue this small, random
    /// means seeing the same advertisement twice running often enough to be
    /// noticed, and rotation is the whole reason a second creative exists.
    /// It is also deterministic, which is what makes it testable.
    ///
    /// - Parameters:
    ///   - previous: the id last shown, or nil on the first advertisement.
    ///   - excluded: ids this player must not be shown - a subscriber is never
    ///     sold the subscription.
    static func next(after previous: String?, excluding excluded: Set<String> = []) -> HouseAd {
        let available = all.filter { !excluded.contains($0.id) }
        // Excluding everything would leave nothing to show, and an empty ad
        // slot is worse than a repeat, so fall back to the full catalogue.
        let pool = available.isEmpty ? all : available
        guard let previous,
              let index = pool.firstIndex(where: { $0.id == previous })
        else { return pool[0] }
        return pool[(index + 1) % pool.count]
    }
}
