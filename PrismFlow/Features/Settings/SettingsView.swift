import SwiftUI
import StoreKit
import PuzzleKit

struct SettingsView: View {

    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss

    @State private var isShowingManageSubscriptions = false
    @State private var isConfirmingReset = false

    var body: some View {
        NavigationStack {
            Form {
                subscriptionSection
                gameplaySection
                accessibilitySection
                purchasesSection
                aboutSection
            }
            .navigationTitle(Text("settings.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: { Text("common.done") }
                }
            }
            .manageSubscriptionsSheet(isPresented: $isShowingManageSubscriptions)
            .confirmationDialog(
                Text("settings.reset.confirmTitle"),
                isPresented: $isConfirmingReset,
                titleVisibility: .visible
            ) {
                Button(role: .destructive) {
                    services.resetProgress()
                } label: {
                    Text("settings.reset.confirm")
                }
                Button(role: .cancel) {} label: { Text("common.cancel") }
            } message: {
                Text("settings.reset.confirmMessage")
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var subscriptionSection: some View {
        Section {
            if services.entitlements.isPro {
                LabeledContent {
                    Text(statusText)
                        .foregroundStyle(services.entitlements.pro.needsAttention ? Ink.danger : Ink.accent)
                } label: {
                    Label("settings.pro.status", systemImage: "crown.fill")
                }
                if let expiry = services.entitlements.pro.expiresAt {
                    LabeledContent {
                        Text(expiry, style: .date)
                    } label: {
                        Text(renewalLabelKey)
                    }
                }
                LabeledContent {
                    Text(services.entitlements.cosmeticsGrantedByPro.count.formatted())
                } label: {
                    Text("settings.pro.includedStyles")
                }
                Button {
                    isShowingManageSubscriptions = true
                } label: {
                    Text("settings.pro.manage")
                }
            } else {
                Text("settings.pro.inactive")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("settings.section.subscription")
        } footer: {
            if services.entitlements.pro.needsAttention {
                Text("settings.pro.billingProblem")
            }
        }
    }

    private var statusText: String {
        let state = services.entitlements.pro
        let key: String
        switch state {
        case .active: key = state.isInTrial ? "settings.pro.trial" : "settings.pro.active"
        case .gracePeriod: key = "settings.pro.grace"
        case .billingRetry: key = "settings.pro.retry"
        case .expired: key = "settings.pro.expired"
        case .revoked: key = "settings.pro.revoked"
        case .notSubscribed: key = "settings.pro.inactive"
        }
        return NSLocalizedString(key, comment: "")
    }

    private var renewalLabelKey: LocalizedStringKey {
        if case .active(_, _, let willRenew) = services.entitlements.pro, willRenew {
            return "settings.pro.renewsOn"
        }
        return "settings.pro.endsOn"
    }

    private var gameplaySection: some View {
        Section {
            Toggle(isOn: binding(\.soundEnabled)) { Text("settings.sound") }
            Toggle(isOn: binding(\.musicEnabled)) { Text("settings.music") }
            Toggle(isOn: binding(\.hapticsEnabled)) { Text("settings.haptics") }
        } header: {
            Text("settings.section.gameplay")
        }
    }

    private var accessibilitySection: some View {
        Section {
            Toggle(isOn: binding(\.colorBlindAssist)) { Text("settings.colorBlind") }
            Toggle(isOn: binding(\.reduceMotion)) { Text("settings.reduceMotion") }
        } header: {
            Text("settings.section.accessibility")
        } footer: {
            Text("settings.accessibilityFooter")
        }
    }

    private var purchasesSection: some View {
        Section {
            Button {
                Task { await services.restorePurchases() }
            } label: {
                Text("shop.restore")
            }
            .disabled(services.store.isRestoring)

            if let banner = services.banner {
                Text(LocalizedStringKey(banner.messageKey))
                    .font(.footnote)
                    .foregroundStyle(banner.style == .failure ? Ink.danger : .secondary)
            }
        } header: {
            Text("settings.section.purchases")
        } footer: {
            Text("settings.restoreFooter")
        }
    }

    private var aboutSection: some View {
        Section {
            Link(destination: LegalLinks.termsOfUse) { Text("legal.terms") }
            Link(destination: LegalLinks.privacyPolicy) { Text("legal.privacy") }
            Link(destination: LegalLinks.support) { Text("settings.support") }

            LabeledContent {
                Text(Self.versionString)
            } label: {
                Text("settings.version")
            }

            Button(role: .destructive) {
                isConfirmingReset = true
            } label: {
                Text("settings.reset")
            }
        } header: {
            Text("settings.section.about")
        } footer: {
            Text("settings.resetFooter")
        }
    }

    // MARK: - Helpers

    private func binding(_ keyPath: WritableKeyPath<GameSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { services.profile.settings[keyPath: keyPath] },
            set: { newValue in
                services.updateSettings { $0[keyPath: keyPath] = newValue }
            }
        )
    }

    static var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
