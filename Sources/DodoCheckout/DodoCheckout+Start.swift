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

        // Record the session so it survives process death; cleared on finish.
        abandonedStore.record(checkoutUrl: checkoutUrl)

        guard let presenter = topPresentedViewController() else {
            inProgressGuard.end()
            abandonedStore.clear()
            throw CheckoutError(code: .platformError, message: "No view controller available to present the checkout.")
        }

        let session = SafariCheckoutSession(returnUrl: returnUrl, onEvent: onEvent)
        activeBrowserSession = session
        defer {
            activeBrowserSession = nil
            abandonedStore.clear()
            inProgressGuard.end()
        }
        return try await session.start(checkoutUrl: checkoutUrl, presenter: presenter)
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
