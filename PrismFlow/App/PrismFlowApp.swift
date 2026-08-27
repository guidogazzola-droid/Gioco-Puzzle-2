import SwiftUI

@main
struct PrismFlowApp: App {

    @State private var services = AppServices()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(services)
                .task {
                    // Start the StoreKit transaction listener before anything
                    // can produce a transaction; a missed update means a player
                    // who paid does not get their content.
                    services.bootstrap()
                }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background, .inactive:
                // The save is small; write it now rather than risk losing the
                // last few levels to a termination.
                services.profileStore.flush()
            case .active:
                Task {
                    await services.store.refreshEntitlements()
                    services.reconcileEquippedCosmetics()
                }
            @unknown default:
                break
            }
        }
    }
}
