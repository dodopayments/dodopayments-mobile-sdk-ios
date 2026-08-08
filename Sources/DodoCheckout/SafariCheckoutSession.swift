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
                let safari = makeSafariViewController(checkoutUrl: checkoutUrl)
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

    /// Builds the sheet with `customization` applied and both delegates wired.
    ///
    /// The statement order here is load-bearing, which is why construction
    /// lives in one place rather than inline at the call site.
    func makeSafariViewController(checkoutUrl: URL) -> SFSafariViewController {
        // `barCollapsingEnabled` is the one field that has to be decided
        // here rather than in `apply`: it lives on the Configuration, which
        // is read once at init and can't be changed afterwards. `nil` means
        // don't touch it at all — leave Configuration()'s own default.
        let configuration = SFSafariViewController.Configuration()
        if let barCollapsingEnabled = customization.barCollapsingEnabled {
            configuration.barCollapsingEnabled = barCollapsingEnabled
        }
        let safari = SFSafariViewController(url: checkoutUrl, configuration: configuration)
        safari.delegate = self
        // `apply` sets `modalPresentationStyle`, and it MUST stay above the
        // `presentationController` access below. Reading that property
        // instantiates a presentation controller from whatever
        // `modalPresentationStyle` says *at that moment*, and UIKit
        // documents that setting the style afterwards has no effect on the
        // presentation: "Always set the value of that property before
        // accessing any presentation controllers."
        // Swapping these two lines silently downgrades a `.fullScreen`
        // request back to the default sheet, and risks dropping the
        // delegate below — the one that reports swipe-to-dismiss.
        apply(customization, to: safari)
        safari.presentationController?.delegate = self
        return safari
    }

    func apply(_ customization: BrowserCustomization, to safari: SFSafariViewController) {
        // `nil` means don't touch these properties at all — leave whatever
        // SFSafariViewController's own current default is in place, rather
        // than asserting a value on the OS's behalf.
        if let dismissButtonStyle = customization.dismissButtonStyle {
            safari.dismissButtonStyle = dismissButtonStyle.uiKitStyle
        }
        if let colorScheme = customization.colorScheme {
            safari.overrideUserInterfaceStyle = colorScheme.uiKitStyle
        }
        // Unlike the other fields, `.pageSheet` here isn't a platform default
        // we're inferring — it was already this SDK's own hardcoded choice
        // before this feature existed, so `nil` resolving to it (rather than
        // skipping the assignment) is deliberate.
        safari.modalPresentationStyle = (customization.presentationStyle ?? .pageSheet).uiKitStyle
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
