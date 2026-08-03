import Foundation

/// Entry point for the Dodo Payments mobile checkout.
///
/// Open Dodo's hosted checkout in an in-app `SFSafariViewController` (iOS) /
/// Custom Tab (Android) and get a clean result from one call:
///
/// ```swift
/// let result = try await DodoCheckout.start(
///     checkoutUrl: checkoutUrl,                 // from your backend
///     returnUrl: URL(string: "myapp://checkout/return")!
/// )
/// ```
///
/// The SDK contains **zero networking code** and holds **no API key**. It
/// watches navigation for your `return_url` and parses the result off the
/// query string. The result is a UI hint — grant access server-side from the
/// webhook.
public enum DodoCheckout {

    // Shared, process-wide state.
    static let abandonedStore = AbandonedSessionStore()
    @MainActor static let inProgressGuard = InProgressGuard()

    /// The session of a checkout that ended without a confirmed outcome, or
    /// `nil`.
    ///
    /// Set whenever the SDK never saw a return URL it could resolve to a
    /// durable outcome — the app was killed mid-flow, `start` returned
    /// `.cancelled` because the user dismissed the browser, or it returned
    /// `.pending`, which is also the fallback for an unparseable return URL.
    /// Check it on launch *and* after every `.cancelled` or `.pending` result,
    /// reconcile the session server-side, then call `clearAbandonedSession()`
    /// once the outcome is terminal.
    public static func getAbandonedSession() -> AbandonedSession? {
        abandonedStore.current()
    }

    /// Clears the abandoned-session record after the merchant has reconciled it.
    public static func clearAbandonedSession() {
        abandonedStore.clear()
    }

    #if canImport(UIKit)
    @MainActor static var activeBrowserSession: SafariCheckoutSession?

    /// Forward incoming URLs here from your own `application(_:open:options:)`
    /// / `.onOpenURL` — `SFSafariViewController` has no in-process way to
    /// catch its own return URL, so the OS routes it back to the app instead.
    /// Returns `true` if the URL belonged to an in-flight checkout (handle it
    /// yourself if `false` — it's unrelated to Dodo).
    @MainActor
    @discardableResult
    public static func handleOpenURL(_ url: URL) -> Bool {
        activeBrowserSession?.handleOpenURL(url) ?? false
    }
    #endif
}
