#if canImport(UIKit)
import SafariServices
import UIKit

/// Backs `DodoCheckout.start`: an in-app `SFSafariViewController` sheet.
/// Chosen over `ASWebAuthenticationSession` — no misleading "wants to Sign
/// In" system dialog, confirmed Apple Pay support, and controlled testing
/// (iOS 26.5 Simulator: a 90s delayed redirect, with and without intervening
/// page activity) did not reproduce the redirect-drop behavior some older
/// reports describe. Not yet verified on a physical device.
@MainActor
final class SafariCheckoutSession: NSObject {
    private let matcher: ReturnUrlMatcher
    private let customization: BrowserCustomization
    private let onEvent: (@Sendable (CheckoutEvent) -> Void)?

    private weak var safariViewController: SFSafariViewController?
    private var continuation: CheckedContinuation<CheckoutResult, Error>?
    private var resumed = false
    private var didConfirmPresentation = false

    init(
        returnUrl: URL,
        customization: BrowserCustomization,
        onEvent: (@Sendable (CheckoutEvent) -> Void)?
    ) {
        self.matcher = ReturnUrlMatcher(returnUrl: returnUrl)
        self.customization = customization
        self.onEvent = onEvent
    }

    func start(checkoutUrl: URL, presenter: UIViewController) async throws -> CheckoutResult {
        onEvent?(.opened)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                let configuration = SFSafariViewController.Configuration()
                // `nil` means don't touch this property at all — leave
                // Configuration()'s own default (currently YES) in place.
                if let barCollapsingEnabled = customization.barCollapsingEnabled {
                    configuration.barCollapsingEnabled = barCollapsingEnabled
                }
                let safari = SFSafariViewController(url: checkoutUrl, configuration: configuration)
                safari.delegate = self
                // Unlike the other fields, `.pageSheet` here isn't a platform
                // default we're inferring — it was already this SDK's own
                // hardcoded choice before this feature existed, so `nil`
                // resolving to it (rather than skipping the assignment) is
                // deliberate.
                safari.modalPresentationStyle = {
                    switch customization.presentationStyle ?? .pageSheet {
                    case .pageSheet: return .pageSheet
                    case .fullScreen: return .fullScreen
                    }
                }()
                safari.presentationController?.delegate = self
                apply(customization, to: safari)
                safariViewController = safari
                presenter.present(safari, animated: true) { [weak self] in
                    self?.didConfirmPresentation = true
                }
                // `present` has no failure signal beyond its completion handler
                // simply never running — e.g. presenting onto a controller that
                // is itself mid-dismissal, which UIKit silently drops. This
                // timeout is the only thing that catches that; don't hang
                // forever. Only counts *foreground* time — if the user
                // backgrounds the app mid-presentation (e.g. to grab a 2FA
                // code), the sheet's animation pauses too, so a plain
                // wall-clock timeout would misfire on a presentation that's
                // actually still going to complete once they return.
                Task { @MainActor [weak self] in
                    let tick = 0.5
                    var foregroundSecondsWaited = 0.0
                    while foregroundSecondsWaited < 5.0 {
                        try? await Task.sleep(nanoseconds: UInt64(tick * 1_000_000_000))
                        guard let self, !self.didConfirmPresentation else { return }
                        if UIApplication.shared.applicationState == .active {
                            foregroundSecondsWaited += tick
                        }
                    }
                    guard let self, !self.didConfirmPresentation else { return }
                    self.fail(
                        with: CheckoutError(
                            code: .platformError,
                            message: "The checkout screen never finished presenting."
                        )
                    )
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.finish(with: CheckoutResult(status: .cancelled), dismiss: true)
            }
        }
    }

    /// Called by `DodoCheckout.handleOpenURL`. Returns `true` if this session
    /// claimed the URL.
    func handleOpenURL(_ url: URL) -> Bool {
        guard matcher.matches(url) else { return false }
        onEvent?(.returnReceived)
        finish(with: ResultParser.parse(url: url), dismiss: true)
        return true
    }

    private func finish(with result: CheckoutResult, dismiss: Bool) {
        guard !resumed else { return }
        resumed = true
        onEvent?(.closed)
        let continuation = self.continuation
        self.continuation = nil
        guard dismiss, let safari = safariViewController, safari.presentingViewController != nil else {
            continuation?.resume(returning: result)
            return
        }
        safari.dismiss(animated: true) {
            continuation?.resume(returning: result)
        }
    }

    private func fail(with error: CheckoutError) {
        guard !resumed else { return }
        resumed = true
        onEvent?(.closed)
        let continuation = self.continuation
        self.continuation = nil
        continuation?.resume(throwing: error)
    }

    private func apply(_ customization: BrowserCustomization, to safari: SFSafariViewController) {
        // `nil` means don't touch these properties at all — leave whatever
        // SFSafariViewController's own current default is in place, rather
        // than asserting a value on the OS's behalf.
        if let dismissButtonStyle = customization.dismissButtonStyle {
            safari.dismissButtonStyle = {
                switch dismissButtonStyle {
                case .done: return .done
                case .close: return .close
                case .cancel: return .cancel
                }
            }()
        }
        if let colorScheme = customization.colorScheme {
            safari.overrideUserInterfaceStyle = {
                switch colorScheme {
                case .system: return .unspecified
                case .light: return .light
                case .dark: return .dark
                }
            }()
        }
    }
}

extension SafariCheckoutSession: SFSafariViewControllerDelegate {
    // `nonisolated` + `assumeIsolated`, not plain `@MainActor`: this class's
    // conformance to a non-isolated protocol only compiles without an
    // explicit hop when the `InferIsolatedConformances` upcoming feature is
    // enabled — true in swift/Package.swift, but not guaranteed in every
    // consumer's build config (RN/Flutter's podspecs don't set it). UIKit
    // always calls delegate methods on the main thread, so the assumption is
    // safe portably, independent of that flag.
    nonisolated func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        MainActor.assumeIsolated {
            // The system is already dismissing the view controller here —
            // don't dismiss again, just resume.
            finish(with: CheckoutResult(status: .cancelled), dismiss: false)
        }
    }
}

extension SafariCheckoutSession: UIAdaptivePresentationControllerDelegate {
    // Fires for the interactive swipe-to-dismiss on the `.pageSheet`, which
    // `safariViewControllerDidFinish` doesn't cover — that one only fires for
    // the "Done" button tap.
    nonisolated func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        MainActor.assumeIsolated {
            finish(with: CheckoutResult(status: .cancelled), dismiss: false)
        }
    }
}
#endif
