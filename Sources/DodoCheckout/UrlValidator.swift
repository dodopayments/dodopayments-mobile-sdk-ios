import Foundation

/// Validates the input passed to `start` before any UI is presented.
enum UrlValidator {
    /// Hosts that a valid `checkoutUrl` may use. Test vs live is read from the
    /// host — there is no mode flag.
    static let allowedCheckoutHosts: Set<String> = [
        "checkout.dodopayments.com",
        "test.checkout.dodopayments.com"
    ]

    /// Throws `INVALID_CHECKOUT_URL` unless `url` is an https Dodo checkout URL
    /// on an allowed host whose path is `/session/…` or an 8-character payment
    /// link id (what a `confirm: true` session returns).
    static func validateCheckoutUrl(_ url: URL) throws {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = components.scheme?.lowercased(),
              scheme == "https",
              let host = components.host?.lowercased(),
              allowedCheckoutHosts.contains(host),
              components.path.hasPrefix("/session/") || isPaymentLinkPath(components.path)
        else {
            throw CheckoutError.invalidCheckoutUrl
        }
    }

    private static func isPaymentLinkPath(_ path: String) -> Bool {
        path.range(of: "^/[A-Za-z0-9_-]{8}/?$", options: .regularExpression) != nil
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
