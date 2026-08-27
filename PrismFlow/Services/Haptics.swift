import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Thin wrapper over the system feedback generators.
///
/// Every call checks the player's setting first, so haptics can be turned off
/// in one place instead of at each call site.
@MainActor
final class HapticsService {

    var isEnabled = true

    enum Event {
        case connect        // a colour completed
        case snap           // one cell added to a trail
        case reject         // an illegal move
        case win
        case reward
    }

    func play(_ event: Event) {
        guard isEnabled else { return }
        #if canImport(UIKit) && !os(watchOS)
        switch event {
        case .snap:
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.5)
        case .connect:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .reject:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .win:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .reward:
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        }
        #endif
    }
}
