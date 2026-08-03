#if canImport(UIKit)
import UIKit

extension DodoCheckout {
    /// Presents Dodo's hosted checkout in an in-app `SFSafariViewController`
    /// and resolves with the outcome once the checkout navigates to
    /// `returnUrl` (or the user closes the screen).
    ///
    /// - Parameters:
    ///   - checkoutUrl: The session URL from your backend. Must be a
    ///     `checkout.dodopayments.com` / `test.checkout.dodopayments.com`
    ///     `/session/…` URL.
    ///   - returnUrl: The URL the SDK watches for. Any absolute URL the
    ///     checkout ends up navigating to; matched on scheme+host+path. Its
    ///     scheme must be registered as a URL type in Info.plist, so the OS
    ///     routes the redirect back to this app. You must also forward
    ///     incoming URLs from your own `application(_:open:options:)` /
    ///     `.onOpenURL` into `DodoCheckout.handleOpenURL(_:)` —
    ///     `SFSafariViewController` has no built-in way to catch its own
    ///     return URL.
    ///   - onEvent: Lifecycle callback for logging/analytics only.
    /// - Returns: A `CheckoutResult` (UI hint — not proof of payment).
    /// - Throws: `CheckoutError` for invalid input, a concurrent checkout, or a
    ///   platform failure. A cancel or a declined payment is a *result*, not a
    ///   thrown error.
    @MainActor
    public static func start(
        checkoutUrl: URL,
        returnUrl: URL,
        onEvent: (@Sendable (CheckoutEvent) -> Void)? = nil
    ) async throws -> CheckoutResult {
        // Validate before touching any UI.
        try UrlValidator.validateCheckoutUrl(checkoutUrl)
        try UrlValidator.validateReturnUrl(returnUrl)

        try inProgressGuard.begin()

        guard let presenter = topPresentedViewController() else {
            inProgressGuard.end()
            throw CheckoutError(code: .platformError, message: "No view controller available to present the checkout.")
        }

        // Record the session so it survives process death *and* a dismissal
        // that beat the return URL. Recorded only once we know we are actually
        // presenting, so a pre-presentation failure never leaves the merchant
        // a phantom session to reconcile.
        abandonedStore.record(checkoutUrl: checkoutUrl)

        let session = SafariCheckoutSession(returnUrl: returnUrl, onEvent: onEvent)
        activeBrowserSession = session
        defer {
            activeBrowserSession = nil
            inProgressGuard.end()
        }

        do {
            let result = try await session.start(checkoutUrl: checkoutUrl, presenter: presenter)
            // Kept on `.cancelled` — see `clearIfOutcomeKnown`. That is the
            // one outcome the SDK cannot vouch for, and the only one the
            // merchant still has to reconcile.
            abandonedStore.clearIfOutcomeKnown(result.status)
            return result
        } catch {
            // Both throws out of `session.start` fire before the sheet is on
            // screen — the already-presenting guard, and the timeout for a
            // presentation that never completed. The checkout page never
            // loaded either way, so there is no payment to reconcile and a
            // record here would only be a phantom. A *cancelled* checkout does
            // not come through here: it returns `.cancelled` normally, task
            // cancellation included.
            abandonedStore.clear()
            throw error
        }
    }

    /// Walks from the key window's root down through presented controllers to
    /// find the one that should present the checkout.
    private static func topPresentedViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        let keyWindow = scenes
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })
            ?? scenes.flatMap { $0.windows }.first

        var top = keyWindow?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}
#endif
