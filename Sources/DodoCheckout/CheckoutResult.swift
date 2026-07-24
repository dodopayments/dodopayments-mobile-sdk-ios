import Foundation

/// The outcome of a checkout, derived entirely from the query string on the
/// merchant's `return_url`.
///
/// This is a **UI signal only**. It is not proof of payment: the SDK never
/// calls the Dodo API and holds no API key. Grant access on your backend from
/// the webhook (`payment.succeeded` / `subscription.active`) or by retrieving
/// the payment with your secret key.
public enum CheckoutStatus: String, Sendable {
    /// One-time payment settled (`status=succeeded`) or subscription became
    /// active (`status=active`).
    case succeeded
    /// The payment was declined (`status=failed`).
    case failed
    /// The user closed the checkout before the return fired.
    case cancelled
    /// The payment will settle later — bank transfers and other async methods
    /// (`status=processing` or any `requires_*`). The webhook delivers the
    /// final outcome.
    case pending
    /// The checkout session expired before completion.
    case expired
}

/// The result handed back from `DodoCheckout.start`.
///
/// Everything here comes from the `return_url` query parameters. `raw` holds
/// the complete, unmodified parameter set so callers can read fields the typed
/// surface does not model.
public struct CheckoutResult: Sendable, Equatable {
    public let status: CheckoutStatus
    public let paymentId: String?
    public let subscriptionId: String?
    public let licenseKeys: [String]?
    public let customerEmail: String?
    /// All query parameters from the `return_url`, verbatim.
    public let raw: [String: String]

    public init(
        status: CheckoutStatus,
        paymentId: String? = nil,
        subscriptionId: String? = nil,
        licenseKeys: [String]? = nil,
        customerEmail: String? = nil,
        raw: [String: String] = [:]
    ) {
        self.status = status
        self.paymentId = paymentId
        self.subscriptionId = subscriptionId
        self.licenseKeys = licenseKeys
        self.customerEmail = customerEmail
        self.raw = raw
    }
}
