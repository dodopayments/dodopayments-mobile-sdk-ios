import Foundation

/// Validates the input passed to `start` before any UI is presented.
enum UrlValidator {
    /// Hosts that a valid `checkoutUrl` may use. Test vs live is read from the
    /// host — there is no mode flag.
    static let allowedCheckoutHosts: Set<String> = [
        "checkout.dodopayments.com",
        "test.checkout.dodopayments.com"
    ]

    /// Throws `INVALID_CHECKOUT_URL` unless `url` is an https Dodo checkout
    /// session URL (`/session/…` path on an allowed host).
    static func validateCheckoutUrl(_ url: URL) throws {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = components.scheme?.lowercased(),
              scheme == "https",
              let host = components.host?.lowercased(),
              allowedCheckoutHosts.contains(host),
              components.path.hasPrefix("/session/")
        else {
            throw CheckoutError.invalidCheckoutUrl
        }
    }

    /// Throws `INVALID_RETURN_URL` unless `url` is a well-formed absolute URL
    /// with both a scheme and a host. The URL need not resolve — a sentinel is
    /// fine, since the SDK cancels the navigation before it loads.
    static func validateReturnUrl(_ url: URL) throws {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = components.scheme, !scheme.isEmpty,
              let host = components.host, !host.isEmpty
        else {
            throw CheckoutError.invalidReturnUrl
        }
    }

}
