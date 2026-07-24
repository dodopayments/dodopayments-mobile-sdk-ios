import Foundation

/// Errors thrown by `DodoCheckout.start`.
///
/// A user cancelling or a payment failing is a **result** (`CheckoutStatus`),
/// never an error. These cases only cover misuse and platform failures.
public struct CheckoutError: Error, Sendable, Equatable {
    public enum Code: String, Sendable {
        /// `checkoutUrl` is not a `checkout.dodopayments.com` /
        /// `test.checkout.dodopayments.com` session URL.
        case invalidCheckoutUrl = "INVALID_CHECKOUT_URL"
        /// `returnUrl` is not a valid absolute URL.
        case invalidReturnUrl = "INVALID_RETURN_URL"
        /// A checkout is already running. Only one can run at a time.
        case alreadyInProgress = "ALREADY_IN_PROGRESS"
        /// An unexpected platform error occurred (e.g. no presenting window).
        case platformError = "PLATFORM_ERROR"
    }

    public let code: Code
    public let message: String

    public init(code: Code, message: String? = nil) {
        self.code = code
        self.message = message ?? code.rawValue
    }

    static let invalidCheckoutUrl = CheckoutError(
        code: .invalidCheckoutUrl,
        message: "checkoutUrl must be a checkout.dodopayments.com or test.checkout.dodopayments.com /session/ URL."
    )
    static let invalidReturnUrl = CheckoutError(
        code: .invalidReturnUrl,
        message: "returnUrl must be a valid absolute URL with a scheme and host."
    )
    static let alreadyInProgress = CheckoutError(
        code: .alreadyInProgress,
        message: "A checkout is already in progress. Only one can run at a time."
    )
}

extension CheckoutError: CustomStringConvertible {
    public var description: String { "\(code.rawValue): \(message)" }
}
