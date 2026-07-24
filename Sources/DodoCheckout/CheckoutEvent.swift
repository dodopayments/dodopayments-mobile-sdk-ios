import Foundation

/// Lifecycle events emitted during a checkout, for logging/analytics only.
///
/// **Never decide the outcome from an event.** Use the `CheckoutResult`
/// returned by `start`. Events carry host-only URL info, never full URLs with
/// query strings.
public enum CheckoutEvent: Sendable, Equatable {
    /// The checkout screen was presented.
    case opened
    /// A navigation matching `returnUrl` was intercepted.
    case returnReceived
    /// The checkout screen was dismissed.
    case closed

    /// Stable string name, matching the cross-platform event vocabulary.
    public var name: String {
        switch self {
        case .opened: return "checkout.opened"
        case .returnReceived: return "checkout.return_received"
        case .closed: return "checkout.closed"
        }
    }
}
